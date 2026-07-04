defmodule Alva.Dispatcher do
  @moduledoc """
  Dynamically routes events from Vue to Ash actions based on Spark DSL.
  """
  require Logger

  def dispatch(event_name, params, opts \\ []) do
    start_time = System.monotonic_time()

    socket = Keyword.get(opts, :socket)
    opts = resolve_auth_opts(event_name, opts, socket)

    result = do_dispatch(event_name, params, opts)

    emit_telemetry(event_name, params, opts, result, start_time)

    result
  end

  defp do_dispatch(event_name, params, opts) do
    domains = Keyword.get(opts, :domains, [])
    ash_opts = Keyword.take(opts, [:actor, :tenant])

    case find_event(domains, event_name) do
      {:ok, resource, event_def} ->
        action_name = event_def.action
        action = Ash.Resource.Info.action(resource, action_name)
        params = Map.drop(params, ["meta", :meta])

        socket = Keyword.get(opts, :socket)

        params =
          if socket, do: consume_uploads_into_params(socket, action, params, opts), else: params

        case action.type do
          :read ->
            if event_def.lookup do
              lookup_field = event_def.lookup
              lookup_key = to_string(lookup_field)
              lookup_value = Map.get(params, lookup_key)
              action_params = Map.delete(params, lookup_key)

              if is_nil(lookup_value) do
                handle_error(not_found_error(resource, lookup_field, lookup_value))
              else
                require Ash.Query
                require Ash.Expr

                query =
                  Ash.Query.for_read(resource, action_name, action_params, ash_opts)
                  |> Ash.Query.filter(^Ash.Expr.ref(lookup_field) == ^lookup_value)

                case Ash.read_one(query, ash_opts) do
                  {:ok, record} when not is_nil(record) ->
                    dispatch_success(record, event_def)

                  {:ok, nil} ->
                    handle_error(not_found_error(resource, lookup_field, lookup_value))

                  {:error, error} ->
                    handle_error(error)
                end
              end
            else
              page_opts = get_indifferent(params, "page", :page)
              sort_opts = get_indifferent(params, "sort", :sort)
              action_params = Map.drop(params, ["page", :page, "sort", :sort])

              read_opts =
                if is_map(page_opts) do
                  valid_keys = ~w(limit offset after before count filter)

                  page_opts =
                    page_opts
                    |> Enum.filter(fn {k, _v} -> to_string(k) in valid_keys end)
                    |> Enum.map(fn {k, v} -> {String.to_existing_atom(to_string(k)), v} end)
                    |> Keyword.new()

                  [page: page_opts]
                else
                  []
                end

              read_opts = Keyword.merge(read_opts, ash_opts)
              query = Ash.Query.for_read(resource, action_name, action_params, ash_opts)

              query =
                if sort_opts do
                  case Ash.Sort.parse_input(resource, sort_opts) do
                    {:ok, valid_sort} -> Ash.Query.sort(query, valid_sort)
                    _ -> query
                  end
                else
                  query
                end

              case Ash.read(query, read_opts) do
                {:ok, %{results: records} = page}
                when is_struct(page, Ash.Page.Offset) or is_struct(page, Ash.Page.Keyset) ->
                  dispatch_success(records, event_def, page)

                {:ok, records} ->
                  dispatch_success(records, event_def)

                {:error, error} ->
                  handle_error(error)
              end
            end

          :create ->
            changeset = Ash.Changeset.for_create(resource, action_name, params, ash_opts)

            if event_def.validate_only do
              handle_dry_run(changeset, event_def)
            else
              case Ash.create(changeset, ash_opts) do
                {:ok, record} ->
                  dispatch_success(record, event_def)

                {:error, error} ->
                  handle_error(error)
              end
            end

          :update ->
            lookup_field = event_def.lookup || :id
            lookup_key = to_string(lookup_field)
            update_params = Map.delete(params, lookup_key)

            with {:ok, record} <- fetch_record(resource, event_def, params, ash_opts),
                 changeset <-
                   Ash.Changeset.for_update(record, action_name, update_params, ash_opts) do
              if event_def.validate_only do
                handle_dry_run(changeset, event_def)
              else
                case Ash.update(changeset, ash_opts) do
                  {:ok, updated_record} ->
                    dispatch_success(updated_record, event_def)

                  {:error, error} ->
                    handle_error(error)
                end
              end
            else
              {:error, error} -> handle_error(error)
            end

          :destroy ->
            with {:ok, record} <- fetch_record(resource, event_def, params, ash_opts),
                 changeset <- Ash.Changeset.for_destroy(record, action_name, %{}, ash_opts) do
              case Ash.destroy(changeset, Keyword.merge([return_destroyed?: true], ash_opts)) do
                {:ok, destroyed_record} ->
                  dispatch_success(destroyed_record, event_def)

                :ok ->
                  dispatch_success(record, event_def)

                {:error, error} ->
                  handle_error(error)
              end
            else
              {:error, error} -> handle_error(error)
            end

          :action ->
            input = Ash.ActionInput.for_action(resource, action_name, params)

            case Ash.run_action(input, ash_opts) do
              {:ok, result} ->
                dispatch_success(result, event_def)

              {:error, error} ->
                handle_error(error)
            end

          _ ->
            Logger.warning(
              "Alva Dispatcher: Action type #{action.type} not supported yet for event #{event_name}"
            )

            %{ok: false, error: %{type: "unsupported", message: "Action type not supported yet"}}
        end

      :error ->
        Logger.warning("Alva Dispatcher: Unknown event #{event_name}")
        %{ok: false, error: %{type: "unknown", message: "Unknown event: #{event_name}"}}
    end
  end

  defp get_indifferent(map, string_key, atom_key) do
    Map.get(map, string_key, Map.get(map, atom_key))
  end

  defp consume_uploads_into_params(socket, action, params, opts) do
    consumer = Keyword.get(opts, :upload_consumer, Phoenix.LiveView)

    file_args =
      Enum.filter(action.arguments || [], fn arg ->
        arg.type == Ash.Type.File or arg.type == {:array, Ash.Type.File}
      end)

    Enum.reduce(file_args, params, fn arg, acc_params ->
      upload_name = arg.name

      uploads = Map.get(socket.assigns || %{}, :uploads, %{})
      upload_config = Map.get(uploads, upload_name)
      entries = if upload_config, do: Map.get(upload_config, :entries, []), else: []

      if upload_config && length(entries) > 0 do
        consumed_files =
          consumer.consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
            # Generate a Plug.Upload representing the file
            {:ok,
             %Plug.Upload{
               path: path,
               filename: entry.client_name,
               content_type: entry.client_type
             }}
          end)

        value =
          if arg.type == {:array, Ash.Type.File} do
            consumed_files
          else
            List.first(consumed_files)
          end

        Map.put(acc_params, to_string(upload_name), value)
      else
        acc_params
      end
    end)
  end

  defp fetch_record(resource, event_def, params, ash_opts) do
    lookup_field = event_def.lookup || :id
    lookup_key = to_string(lookup_field)
    lookup_value = Map.get(params, lookup_key)
    Ash.get(resource, [{lookup_field, lookup_value}], ash_opts)
  end

  defp handle_dry_run(changeset, _event_def) do
    if changeset.valid? do
      %{ok: true, data: %{}}
    else
      handle_error(Ash.Error.to_error_class(changeset.errors, changeset: changeset))
    end
  end

  defp dispatch_success(record_or_list, event_def, page \\ nil) do
    {stripped, exposed_meta} = strip_and_extract_metadata(record_or_list, event_def)

    if page do
      handle_success(stripped, exposed_meta, page)
    else
      handle_success(stripped, exposed_meta)
    end
  end

  defp find_event(domains, event_name) do
    Enum.find_value(domains, :error, fn domain ->
      map = Alva.Domain.Info.alva_event_map(domain)

      case Map.fetch(map, event_name) do
        {:ok, {resource, event}} -> {:ok, resource, event}
        :error -> nil
      end
    end)
  end

  def strip_and_extract_metadata(record, event_def) when is_map(record) do
    expose_keys = event_def.expose_metadata
    exposed_meta = extract_exposed_metadata(record, expose_keys)
    {strip_metadata(record), exposed_meta}
  end

  # For lists, extract metadata from the first record only.
  # All records in a query share the same execution metadata.
  def strip_and_extract_metadata(list, event_def) when is_list(list) do
    expose_keys = event_def.expose_metadata

    exposed_meta =
      case list do
        [first | _] -> extract_exposed_metadata(first, expose_keys)
        [] -> %{}
      end

    {strip_metadata(list), exposed_meta}
  end

  # Non-map/list results (strings, etc.) — no metadata to extract
  def strip_and_extract_metadata(result, _event_def) do
    {strip_metadata(result), %{}}
  end

  defp extract_exposed_metadata(_record, []), do: %{}

  defp extract_exposed_metadata(%{__metadata__: metadata}, keys) when is_map(metadata) do
    metadata
    |> Map.take(keys)
    |> Enum.into(%{})
  end

  defp extract_exposed_metadata(_, _), do: %{}

  def strip_metadata(%module{} = record) do
    if Ash.Resource.Info.resource?(module) do
      fields = public_fields(module)

      record
      |> Map.take(fields)
      |> Enum.reject(fn {_k, v} ->
        match?(%Ash.NotLoaded{}, v) or match?(%Ash.ForbiddenField{}, v)
      end)
      |> Enum.map(fn {k, v} -> {k, strip_metadata(v)} end)
      |> Enum.into(%{})
    else
      record
      |> Map.from_struct()
      |> drop_metadata()
    end
  end

  def strip_metadata(list) when is_list(list) do
    Enum.map(list, &strip_metadata/1)
  end

  def strip_metadata(%{} = map) when not is_struct(map) do
    drop_metadata(map)
  end

  def strip_metadata(other), do: other

  defp drop_metadata(map) do
    Map.drop(map, [:__meta__, :__metadata__])
  end

  defp public_fields(resource) do
    Alva.Resource.Info.public_fields(resource)
  end

  defp not_found_error(resource, lookup_field, lookup_value) do
    Ash.Error.Query.NotFound.exception(
      resource: resource,
      primary_key: %{lookup_field => lookup_value}
    )
  end

  defp handle_success(data, exposed_meta) do
    {permissions, cleaned_data} = extract_and_remove_permissions(data)
    meta = build_meta(permissions, exposed_meta)

    if map_size(meta) > 0 do
      %{ok: true, data: cleaned_data, meta: meta}
    else
      %{ok: true, data: cleaned_data}
    end
  end

  defp handle_success(data, exposed_meta, page) do
    {permissions, cleaned_data} = extract_and_remove_permissions(data)

    meta_pagination =
      %{
        limit: page.limit,
        offset: page.offset,
        count: page.count,
        has_more: page.more?
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.into(%{})

    meta = Map.merge(%{pagination: meta_pagination}, build_meta(permissions, exposed_meta))
    %{ok: true, data: cleaned_data, meta: meta}
  end

  defp build_meta(permissions, exposed_meta) do
    meta = if map_size(permissions) > 0, do: %{_permissions: permissions}, else: %{}
    Map.merge(meta, exposed_meta)
  end

  defp extract_and_remove_permissions(data) when is_list(data) do
    if data == [] do
      {%{}, []}
    else
      {permissions, _} = extract_permissions_from_map(hd(data))

      new_data =
        Enum.map(data, fn item ->
          {_, cleaned} = extract_permissions_from_map(item)
          cleaned
        end)

      {permissions, new_data}
    end
  end

  defp extract_and_remove_permissions(data) when is_map(data) do
    extract_permissions_from_map(data)
  end

  defp extract_and_remove_permissions(other), do: {%{}, other}

  defp extract_permissions_from_map(map) when is_map(map) do
    {perms, rest} =
      Map.split_with(map, fn {k, _v} ->
        String.starts_with?(to_string(k), "can_")
      end)

    {Map.new(perms), Map.new(rest)}
  end

  defp extract_permissions_from_map(other), do: {%{}, other}

  defp handle_error(error) do
    %{ok: false, error: Alva.Error.format(error)}
  end

  defp resolve_auth_opts(event_name, opts, socket) do
    if is_nil(socket) do
      opts
    else
      user_key = Application.get_env(:alva, :actor_assign_key, :current_user)
      tenant_key = Application.get_env(:alva, :tenant_assign_key, :current_tenant)

      actor = Map.get(socket.assigns, user_key)
      tenant = Map.get(socket.assigns, tenant_key)

      if is_nil(actor) and not Keyword.has_key?(opts, :actor) do
        Logger.warning(
          "Alva Extension: Dispatching event #{inspect(event_name)} without an actor. Expected socket.assigns.#{user_key} to be set."
        )
      end

      if is_nil(tenant) and not Keyword.has_key?(opts, :tenant) do
        Logger.warning(
          "Alva Extension: Dispatching event #{inspect(event_name)} without a tenant. Expected socket.assigns.#{tenant_key} to be set."
        )
      end

      opts
      |> (fn o -> if actor, do: Keyword.put_new(o, :actor, actor), else: o end).()
      |> (fn o -> if tenant, do: Keyword.put_new(o, :tenant, tenant), else: o end).()
    end
  end

  defp emit_telemetry(event_name, params, opts, result, start_time) do
    duration = System.monotonic_time() - start_time
    actor = Keyword.get(opts, :actor)
    tenant = Keyword.get(opts, :tenant)

    metadata = %{
      event_name: event_name,
      params: params,
      actor: actor,
      tenant: tenant,
      result: result
    }

    :telemetry.execute([:alva, :dispatch, :stop], %{duration: duration}, metadata)
  end
end
