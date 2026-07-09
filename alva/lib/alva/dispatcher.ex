defmodule Alva.Dispatcher do
  @moduledoc """
  Dynamically routes events from Vue to Ash actions based on Spark DSL.
  """
  require Logger

  @upload_temp_dir_name "alva_uploads"

  def dispatch(event_name, params, opts \\ []) do
    start_time = System.monotonic_time()

    socket = Keyword.get(opts, :socket)

    opts =
      opts
      |> resolve_registry_opts(socket)
      |> resolve_auth_opts(event_name, socket)

    result = do_dispatch(event_name, params, opts)

    emit_telemetry(event_name, params, opts, result, start_time)

    result
  end

  defp do_dispatch(event_name, params, opts) do
    ash_opts = Keyword.take(opts, [:actor, :tenant])

    case find_event(opts, event_name) do
      {:ok, resource, event_def} ->
        action_name = event_def.action
        action = Ash.Resource.Info.action(resource, action_name)
        params = Map.drop(params, ["meta", :meta])

        # Unwrap form params if it matches the event name (standard LiveVue form submission)
        params =
          case Map.fetch(params, event_name) do
            {:ok, unwrapped} when is_map(unwrapped) -> unwrapped
            _ -> params
          end

        socket = Keyword.get(opts, :socket)

        {params, persisted_upload_paths} =
          if socket do
            consume_uploads_into_params(socket, action, params, opts)
          else
            {params, []}
          end

        try do
          execute_action(action.type, resource, action, event_def, params, ash_opts, event_name)
        after
          cleanup_persisted_uploads(persisted_upload_paths)
        end

      :error ->
        Logger.warning("Alva Dispatcher: Unknown event #{event_name}")
        %{ok: false, error: %{type: "unknown", message: "Unknown event: #{event_name}"}}
    end
  end

  defp execute_action(:read, resource, action, event_def, params, ash_opts, _event_name) do
    if event_def.lookup do
      handle_read_with_lookup(resource, event_def, params, ash_opts)
    else
      handle_read(resource, action, event_def, params, ash_opts)
    end
  end

  defp execute_action(:create, resource, _action, event_def, params, ash_opts, _event_name) do
    changeset = Ash.Changeset.for_create(resource, event_def.action, params, ash_opts)

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
  end

  defp execute_action(:update, resource, _action, event_def, params, ash_opts, _event_name) do
    lookup_field = event_def.lookup || :id
    lookup_key = to_string(lookup_field)
    update_params = Map.delete(params, lookup_key)

    with {:ok, record} <- fetch_record(resource, event_def, params, ash_opts),
         changeset <- Ash.Changeset.for_update(record, event_def.action, update_params, ash_opts) do
      apply_update_changeset(changeset, event_def, ash_opts)
    else
      {:error, error} -> handle_error(error)
    end
  end

  defp execute_action(:destroy, resource, _action, event_def, params, ash_opts, _event_name) do
    with {:ok, record} <- fetch_record(resource, event_def, params, ash_opts),
         changeset <- Ash.Changeset.for_destroy(record, event_def.action, %{}, ash_opts) do
      case Ash.destroy(changeset, Keyword.merge([return_destroyed?: true], ash_opts)) do
        {:ok, destroyed_record} ->
          dispatch_success(destroyed_record, event_def)

        {:error, error} ->
          handle_error(error)
      end
    else
      {:error, error} -> handle_error(error)
    end
  end

  defp execute_action(:action, resource, _action, event_def, params, ash_opts, _event_name) do
    input = Ash.ActionInput.for_action(resource, event_def.action, params)

    case Ash.run_action(input, ash_opts) do
      {:ok, result} ->
        dispatch_success(result, event_def)

      {:error, error} ->
        handle_error(error)
    end
  end

  defp apply_update_changeset(changeset, event_def, ash_opts) do
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
  end

  defp handle_read_with_lookup(resource, event_def, params, ash_opts) do
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
        Ash.Query.for_read(resource, event_def.action, action_params, ash_opts)
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
  end

  defp handle_read(resource, action, event_def, params, ash_opts) do
    action_params = Map.drop(params, ["page", :page, "sort", :sort])
    read_opts = build_read_opts(params, action, resource, ash_opts)
    query = build_read_query(resource, event_def.action, action_params, params, ash_opts)

    case Ash.read(query, read_opts) do
      {:ok, page} when is_struct(page, Ash.Page.Offset) or is_struct(page, Ash.Page.Keyset) ->
        handle_read_result(page.results, action, event_def, resource, page)

      {:ok, records} ->
        handle_read_result(records, action, event_def, resource, nil)

      {:error, error} ->
        handle_error(error)
    end
  end

  defp handle_read_result(records, action, event_def, resource, page) do
    cond do
      action.get? ->
        case records do
          [record | _] ->
            dispatch_success(record, event_def, page)

          [] ->
            handle_error(Ash.Error.Query.NotFound.exception(resource: resource, primary_key: %{}))
        end

      page ->
        dispatch_success(records, event_def, page)

      true ->
        dispatch_success(records, event_def)
    end
  end

  defp build_read_opts(params, action, resource, ash_opts) do
    page_opts = get_indifferent(params, "page", :page)
    read_opts = resolve_page_opts(page_opts, action, resource)
    Keyword.merge(read_opts, ash_opts)
  end

  defp resolve_page_opts(page_opts, _action, _resource) when is_map(page_opts) do
    valid_keys = ~w(limit offset after before count filter)

    mapped =
      page_opts
      |> Enum.filter(fn {k, _v} -> to_string(k) in valid_keys end)
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(to_string(k)), v} end)
      |> Keyword.new()

    [page: mapped]
  end

  defp resolve_page_opts(_page_opts, action, resource) do
    cond do
      action.pagination ->
        Logger.warning(
          "Alva Dispatcher: Action #{action.name} on #{inspect(resource)} is paginated but no page options were provided. Enforcing default limit: 50."
        )

        [page: [limit: 50]]

      action.get? ->
        []

      true ->
        Logger.warning(
          "Alva Dispatcher: Action #{action.name} on #{inspect(resource)} returns a collection but has no pagination configured in Ash. This may block LiveView on large payloads."
        )

        []
    end
  end

  defp build_read_query(resource, action_name, action_params, params, ash_opts) do
    sort_opts = get_indifferent(params, "sort", :sort)
    query = Ash.Query.for_read(resource, action_name, action_params, ash_opts)

    if sort_opts do
      case Ash.Sort.parse_input(resource, sort_opts) do
        {:ok, valid_sort} -> Ash.Query.sort(query, valid_sort)
        _ -> query
      end
    else
      query
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

    Enum.reduce(file_args, {params, []}, fn arg, {acc_params, acc_cleanup_paths} ->
      upload_name = arg.name

      uploads = Map.get(socket.assigns || %{}, :uploads, %{})
      upload_config = Map.get(uploads, upload_name)
      entries = if upload_config, do: Map.get(upload_config, :entries, []), else: []

      if upload_config && entries != [] do
        {value, cleanup_paths} = consume_upload(consumer, socket, upload_name, arg.type)
        {Map.put(acc_params, to_string(upload_name), value), acc_cleanup_paths ++ cleanup_paths}
      else
        {acc_params, acc_cleanup_paths}
      end
    end)
  end

  defp consume_upload(consumer, socket, upload_name, arg_type) do
    {consumed_files, cleanup_paths} =
      consumer.consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
        {:ok, persist_uploaded_entry(path, entry)}
      end)
      |> Enum.unzip()

    value = maybe_wrap_upload_list(consumed_files, arg_type)
    {value, cleanup_paths}
  end

  defp maybe_wrap_upload_list(files, {:array, _}), do: files
  defp maybe_wrap_upload_list(files, _), do: List.first(files)

  defp persist_uploaded_entry(path, entry) do
    upload_dir = Path.join(System.tmp_dir!(), @upload_temp_dir_name)
    File.mkdir_p!(upload_dir)

    original_name = entry.client_name || Path.basename(path)
    persisted_path = build_persisted_upload_path(upload_dir, original_name)
    File.cp!(path, persisted_path)

    {%Plug.Upload{path: persisted_path, filename: original_name, content_type: entry.client_type},
     persisted_path}
  end

  defp build_persisted_upload_path(upload_dir, original_name) do
    basename =
      original_name
      |> Path.basename()
      |> Path.rootname()
      |> String.replace(~r/[^A-Za-z0-9._-]+/, "_")
      |> String.trim("_")
      |> case do
        "" -> "upload"
        value -> value
      end

    ext = Path.extname(original_name)
    filename = "#{basename}-#{System.unique_integer([:positive])}#{ext}"
    Path.join(upload_dir, filename)
  end

  defp fetch_record(resource, event_def, params, ash_opts) do
    lookup_field = event_def.lookup || :id
    lookup_key = to_string(lookup_field)
    lookup_value = Map.get(params, lookup_key)
    Ash.get(resource, [{lookup_field, lookup_value}], ash_opts)
  end

  defp cleanup_persisted_uploads(paths) do
    Enum.each(paths, &File.rm/1)
  end

  defp handle_dry_run(changeset, _event_def) do
    if changeset.valid? do
      %{ok: true, data: %{}}
    else
      handle_error(Ash.Error.to_error_class(changeset.errors, changeset: changeset))
    end
  end

  defp dispatch_success(record_or_list, event_def, page \\ nil) do
    {stripped, exposed_meta} =
      Alva.Serializer.serialize(record_or_list, expose_metadata: event_def.expose_metadata)

    handle_success(stripped, exposed_meta, page)
  end

  defp find_event(opts, event_name) do
    case Keyword.get(opts, :otp_app) do
      otp_app when is_atom(otp_app) and not is_nil(otp_app) ->
        Alva.Registry.fetch_event(otp_app, event_name)

      _ ->
        find_event_in_domains(Keyword.get(opts, :domains, []), event_name)
    end
  end

  defp find_event_in_domains(domains, event_name) do
    Enum.find_value(domains, :error, fn domain ->
      map = Alva.Registry.alva_event_map(domain)

      case Map.fetch(map, event_name) do
        {:ok, {resource, event}} -> {:ok, resource, event}
        :error -> nil
      end
    end)
  end

  defp not_found_error(resource, lookup_field, lookup_value) do
    Ash.Error.Query.NotFound.exception(
      resource: resource,
      primary_key: %{lookup_field => lookup_value}
    )
  end

  defp handle_success(data, exposed_meta, page \\ nil) do
    {permissions, cleaned_data} = extract_and_remove_permissions(data)

    meta =
      if page do
        pagination = %{
          limit: page.limit,
          offset: page.offset,
          count: page.count,
          has_more: page.more?
        }

        pagination = pagination |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Enum.into(%{})
        Map.merge(%{pagination: pagination}, build_meta(permissions, exposed_meta))
      else
        build_meta(permissions, exposed_meta)
      end

    if map_size(meta) > 0 do
      %{ok: true, data: cleaned_data, meta: meta}
    else
      %{ok: true, data: cleaned_data}
    end
  end

  defp build_meta(permissions, exposed_meta) do
    meta = if map_size(permissions) > 0, do: %{_permissions: permissions}, else: %{}
    Map.merge(meta, exposed_meta)
  end

  defp extract_and_remove_permissions([]), do: {%{}, []}

  defp extract_and_remove_permissions([first | _] = data) when is_list(data) do
    {permissions, _} = extract_permissions_from_map(first)

    new_data =
      Enum.map(data, fn item ->
        {_, cleaned} = extract_permissions_from_map(item)
        cleaned
      end)

    {permissions, new_data}
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

  defp resolve_registry_opts(opts, socket) do
    case Keyword.fetch(opts, :otp_app) do
      {:ok, otp_app} when is_atom(otp_app) and not is_nil(otp_app) ->
        opts

      _ ->
        case Alva.Registry.otp_app(socket) do
          otp_app when is_atom(otp_app) and not is_nil(otp_app) ->
            Keyword.put(opts, :otp_app, otp_app)

          _ ->
            opts
        end
    end
  end

  defp resolve_auth_opts(opts, _event_name, nil), do: opts

  defp resolve_auth_opts(opts, event_name, socket) do
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
    |> maybe_put(:actor, actor)
    |> maybe_put(:tenant, tenant)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put_new(opts, key, value)

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
