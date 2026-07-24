defmodule Alva.Dispatcher.Context do
  @moduledoc false
  defstruct [:event_name, :params, :actor, :tenant, :opts]
end

defmodule Alva.Dispatcher do
  @moduledoc since: "0.1.0"
  @moduledoc """
  Dynamically routes events from Vue to Ash actions based on Spark DSL.

  This is the core routing engine of Alva. When the frontend calls an event
  (e.g. `alva.catalog.list_products()`), the `dispatch/3` function resolves
  the event name against the `Alva.Registry`, looks up the target `Ash.Resource`
  action, executes it, and returns a normalized result.

  ## Event Resolution

  Events are resolved either through an `:otp_app` (host application) or a list of
  `:domains`. The dispatcher also handles:

    - File upload consumption via `Phoenix.LiveView` upload entries
    - Actor and tenant injection from socket assigns
    - Pagination options (`:page`, `:sort`)
    - Dry-run validation for create/update events (`validate_only`)
    - Telemetry instrumentation (`[:alva, :dispatch, :stop]`)

  See `Alva.Resource` for how events are defined, and `Alva.LiveView` for how
  dispatching is wired into the LiveView lifecycle.
  """
  require Logger

  alias Ash.Error.Query.NotFound
  alias Ash.Resource.Info
  alias Alva.Dispatcher.Context

  @doc """
  Routes a frontend event to the matching Ash action.

  ## Options

    * `:socket` - A `Phoenix.LiveView.Socket` for upload consumption and auth resolution.
    * `:otp_app` - The host OTP app for registry lookup.
    * `:domains` - A list of `Ash.Domain` modules (used when `:otp_app` is not provided).
    * `:actor` - The actor for Ash authorization (auto-resolved from socket assigns).
    * `:tenant` - The tenant for Ash multitenancy (auto-resolved from socket assigns).

  Returns `%{ok: true, data: payload}` on success, or
  `%{ok: false, error: error_map}` on failure.
  """
  @doc since: "0.1.0"
  def dispatch(event_name, params, opts \\ []) do
    start_time = System.monotonic_time()

    actor = Keyword.get(opts, :actor)
    tenant = Keyword.get(opts, :tenant)

    if is_nil(actor) do
      Logger.warning(
        "Alva Extension: Dispatching event #{inspect(event_name)} without an actor. Expected socket.assigns.current_user to be set."
      )
    end

    if is_nil(tenant) do
      Logger.warning(
        "Alva Extension: Dispatching event #{inspect(event_name)} without a tenant. Expected socket.assigns.current_tenant to be set."
      )
    end

    context = %Context{
      event_name: event_name,
      params: params,
      actor: actor,
      tenant: tenant,
      opts: Keyword.take(opts, [:actor, :tenant])
    }

    start_meta = Map.from_struct(context)

    :telemetry.execute(
      [:alva, :dispatch, :start],
      %{system_time: System.system_time()},
      start_meta
    )

    try do
      result = do_dispatch(context, opts)
      duration = System.monotonic_time() - start_time

      stop_meta = Map.put(start_meta, :result, result)
      :telemetry.execute([:alva, :dispatch, :stop], %{duration: duration}, stop_meta)

      result
    catch
      kind, reason ->
        duration = System.monotonic_time() - start_time

        exception_meta =
          Map.merge(start_meta, %{kind: kind, reason: reason, stacktrace: __STACKTRACE__})

        :telemetry.execute([:alva, :dispatch, :exception], %{duration: duration}, exception_meta)
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  # ==========================================
  # EVENT DISPATCH & RESOLUTION
  # ==========================================

  # Internal entrypoint for resolving event definitions, consuming file uploads, and executing actions
  defp do_dispatch(%Context{event_name: event_name} = context, opts) do
    case find_event(opts, event_name) do
      {:ok, resource, event_def} ->
        action_name = event_def.action
        action = Info.action(resource, action_name)
        params = Map.drop(context.params, ["meta", :meta])

        # Unwrap form params if it matches the event name (standard LiveVue form submission)
        params =
          case Map.fetch(params, event_name) do
            {:ok, unwrapped} when is_map(unwrapped) -> unwrapped
            _ -> params
          end

        socket = Keyword.get(opts, :socket)

        {params, cleanup_paths} =
          if socket && action do
            Alva.LiveView.Uploads.consume_uploads_into_params(socket, action, params, opts)
          else
            {params, []}
          end

        context = %{context | params: params}

        try do
          execute_action(action.type, resource, action, event_def, context)
        after
          Alva.LiveView.Uploads.cleanup_persisted_uploads(cleanup_paths)
        end

      :error ->
        Logger.warning("Alva Dispatcher: Unknown event #{event_name}")
        %{ok: false, error: %{type: "unknown", message: "Unknown event: #{event_name}"}}
    end
  end

  # Resolves event definition from OTP app registry or explicit domain list
  defp find_event(opts, event_name) do
    otp_app =
      Keyword.get(opts, :otp_app) ||
        case Keyword.get(opts, :socket) do
          %Phoenix.LiveView.Socket{} = socket -> Alva.Registry.otp_app(socket)
          _ -> nil
        end

    if otp_app do
      Alva.Registry.fetch_event(otp_app, event_name)
    else
      find_event_in_domains(Keyword.get(opts, :domains, []), event_name)
    end
  end

  # Fallback search across explicit list of Ash Domain modules
  defp find_event_in_domains(domains, event_name) do
    Enum.find_value(domains, :error, fn domain ->
      map = Alva.Registry.alva_event_map(domain)

      case Map.fetch(map, event_name) do
        {:ok, {resource, event}} -> {:ok, resource, event}
        :error -> nil
      end
    end)
  end

  # ==========================================
  # ACTION EXECUTION HANDLERS
  # ==========================================

  # Executes a read action without lookup parameter
  defp execute_action(
         :read,
         resource,
         action,
         %{lookup: nil} = event_def,
         context
       ) do
    handle_read(resource, action, event_def, context)
  end

  # Executes a read action using a primary key / lookup parameter
  defp execute_action(
         :read,
         resource,
         _action,
         %{lookup: lookup} = event_def,
         context
       )
       when not is_nil(lookup) do
    handle_read_with_lookup(resource, event_def, context)
  end

  # Executes a create action (persisted or validate_only dry-run)
  defp execute_action(:create, resource, _action, event_def, context) do
    changeset = Ash.Changeset.for_create(resource, event_def.action, context.params, context.opts)

    if event_def.validate_only do
      handle_dry_run(changeset, event_def)
    else
      case Ash.create(changeset, context.opts) do
        {:ok, record} ->
          dispatch_success(record, event_def)

        {:error, error} ->
          handle_error(error)
      end
    end
  end

  # Executes an update action using primary key lookup
  defp execute_action(:update, resource, _action, event_def, context) do
    lookup_field = event_def.lookup || :id
    lookup_key = to_string(lookup_field)
    update_params = Map.delete(context.params, lookup_key)

    with {:ok, record} <- fetch_record(resource, event_def, context),
         changeset <-
           Ash.Changeset.for_update(record, event_def.action, update_params, context.opts) do
      apply_update_changeset(changeset, event_def, context.opts)
    else
      {:error, error} -> handle_error(error)
    end
  end

  # Executes a destroy action using primary key lookup
  defp execute_action(:destroy, resource, _action, event_def, context) do
    with {:ok, record} <- fetch_record(resource, event_def, context),
         changeset <- Ash.Changeset.for_destroy(record, event_def.action, %{}, context.opts) do
      case Ash.destroy(changeset, Keyword.merge([return_destroyed?: true], context.opts)) do
        {:ok, destroyed_record} ->
          dispatch_success(destroyed_record, event_def)

        {:error, error} ->
          handle_error(error)
      end
    else
      {:error, error} -> handle_error(error)
    end
  end

  # Executes a generic action (Ash.ActionInput)
  defp execute_action(:action, resource, _action, event_def, context) do
    input = Ash.ActionInput.for_action(resource, event_def.action, context.params)

    case Ash.run_action(input, context.opts) do
      {:ok, result} ->
        dispatch_success(result, event_def)

      {:error, error} ->
        handle_error(error)
    end
  end

  # Applies update changeset or handles validate_only dry-run
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

  # Handles read actions filtered by a single lookup field (e.g. id)
  defp handle_read_with_lookup(resource, event_def, context) do
    lookup_field = event_def.lookup
    lookup_key = to_string(lookup_field)
    lookup_value = Map.get(context.params, lookup_key)
    action_params = Map.delete(context.params, lookup_key)

    if is_nil(lookup_value) do
      handle_error(not_found_error(resource, lookup_field, lookup_value))
    else
      require Ash.Query
      require Ash.Expr

      query =
        Ash.Query.for_read(resource, event_def.action, action_params, context.opts)
        |> Ash.Query.filter(^Ash.Expr.ref(lookup_field) == ^lookup_value)

      case Ash.read_one(query, context.opts) do
        {:ok, record} when not is_nil(record) ->
          dispatch_success(record, event_def)

        {:ok, nil} ->
          handle_error(not_found_error(resource, lookup_field, lookup_value))

        {:error, error} ->
          handle_error(error)
      end
    end
  end

  # Fetches a single record by primary key / lookup field for update/destroy actions
  defp fetch_record(resource, event_def, context) do
    lookup_field = event_def.lookup || :id
    lookup_key = to_string(lookup_field)
    lookup_value = Map.get(context.params, lookup_key)
    Ash.get(resource, [{lookup_field, lookup_value}], context.opts)
  end

  # Handles validate_only dry-run for form validation without persistence
  defp handle_dry_run(changeset, _event_def) do
    if changeset.valid? do
      %{ok: true, data: %{}}
    else
      handle_error(Ash.Error.to_error_class(changeset.errors, changeset: changeset))
    end
  end

  # ==========================================
  # READ QUERY & PAGINATION HELPERS
  # ==========================================

  # Handles execution of collection/list read actions with pagination and sorting
  defp handle_read(resource, action, event_def, context) do
    action_params = Map.drop(context.params, ["page", :page, "sort", :sort])
    read_opts = build_read_opts(context.params, action, resource, context.opts)

    query =
      build_read_query(resource, event_def.action, action_params, context.params, context.opts)

    case Ash.read(query, read_opts) do
      {:ok, page} when is_struct(page, Ash.Page.Offset) or is_struct(page, Ash.Page.Keyset) ->
        handle_read_result(page.results, action, event_def, resource, page)

      {:ok, records} ->
        handle_read_result(records, action, event_def, resource, nil)

      {:error, error} ->
        handle_error(error)
    end
  end

  # Processes read query result items and formats single record vs list responses
  defp handle_read_result(records, action, event_def, resource, page) do
    cond do
      action.get? ->
        case records do
          [record | _] ->
            dispatch_success(record, event_def, page)

          [] ->
            handle_error(NotFound.exception(resource: resource, primary_key: %{}))
        end

      page ->
        dispatch_success(records, event_def, page)

      true ->
        dispatch_success(records, event_def)
    end
  end

  # Constructs read options including pagination limits and Ash action options
  defp build_read_opts(params, action, resource, ash_opts) do
    page_opts = get_indifferent(params, "page", :page)
    read_opts = resolve_page_opts(page_opts, action, resource)
    Keyword.merge(read_opts, ash_opts)
  end

  # Builds an Ash.Query for read actions, parsing sorting parameters if present
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

  # Resolves pagination options or applies safe defaults / logs warnings for unpaginated queries
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

  # ==========================================
  # RESPONSE FORMATTING & METADATA HELPERS
  # ==========================================

  # Serializes records and wraps successful responses with exposed metadata
  defp dispatch_success(record_or_list, event_def, page \\ nil) do
    {stripped, exposed_meta} =
      Alva.Serializer.serialize(record_or_list, expose_metadata: event_def.expose_metadata)

    handle_success(stripped, exposed_meta, page)
  end

  # Constructs response map containing ok: true, data, and optional meta block
  defp handle_success(data, exposed_meta, page) do
    {permissions, cleaned_data} = extract_and_remove_permissions(data)
    meta = build_response_meta(permissions, exposed_meta, page)

    if map_size(meta) > 0 do
      %{ok: true, data: cleaned_data, meta: meta}
    else
      %{ok: true, data: cleaned_data}
    end
  end

  # Builds response metadata for unpaginated queries
  defp build_response_meta(permissions, exposed_meta, nil) do
    build_meta(permissions, exposed_meta)
  end

  # Builds response metadata including pagination statistics for paginated queries
  defp build_response_meta(permissions, exposed_meta, page) do
    pagination =
      %{limit: page.limit, offset: page.offset, count: page.count, has_more: page.more?}
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.into(%{})

    Map.merge(%{pagination: pagination}, build_meta(permissions, exposed_meta))
  end

  # Combines _permissions map with explicitly exposed metadata keys
  defp build_meta(permissions, exposed_meta) do
    meta = if map_size(permissions) > 0, do: %{_permissions: permissions}, else: %{}
    Map.merge(meta, exposed_meta)
  end

  # Extracts can_* permission fields from response items and separates them into _permissions
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

  # Helper for extracting keys beginning with "can_" from a map
  defp extract_permissions_from_map(map) when is_map(map) do
    {perms, rest} =
      Map.split_with(map, fn {k, _v} ->
        String.starts_with?(to_string(k), "can_")
      end)

    {Map.new(perms), Map.new(rest)}
  end

  defp extract_permissions_from_map(other), do: {%{}, other}

  # Formats runtime errors via Alva.Error into a normalized %{ok: false, error: ...} payload
  defp handle_error(error) do
    %{ok: false, error: Alva.Error.format(error)}
  end

  # Helper to construct a NotFound exception struct
  defp not_found_error(resource, lookup_field, lookup_value) do
    NotFound.exception(
      resource: resource,
      primary_key: %{lookup_field => lookup_value}
    )
  end

  # Looks up a key in a map using string or atom representation
  defp get_indifferent(map, string_key, atom_key) do
    Map.get(map, string_key, Map.get(map, atom_key))
  end
end
