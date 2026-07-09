defmodule Alva.LiveView do
  @moduledoc """
  A macro to inject Alva-specific functionality into Phoenix LiveViews.
  """

  @alva_private_key :alva
  @public_activation_keys [
    :streams,
    :uploads
  ]
  @upload_change_event "alva.validate_upload"
  @upload_submit_event "alva.save_upload"
  @err_domains_removed "Alva declarative page activation no longer accepts `domains:`. Prefer `subscriptions:` for the supported V2 path; projection lookup now resolves through the consuming host app registry."

  @err_opts_expected "use Alva.LiveView expects keyword options. The V2 path only accepts `streams:` and `uploads:`. Legacy keys are no longer supported."
  defp err_unsupported_key(key),
    do:
      "Alva declarative page activation only accepts :streams and :uploads on the supported V2 path. Unsupported key: #{inspect(key)}. The V1 legacy keys are removed."

  defmacro __using__(opts) do
    validate_use_opts!(opts, __CALLER__)

    if Keyword.has_key?(opts, :subscriptions) do
      raise CompileError,
        description:
          "The legacy `subscriptions:` DSL is strictly removed. Use `streams:` instead."
    end

    quote do
      import Alva.LiveView
      @alva_streams Keyword.get(unquote(opts), :streams, [])
      @alva_uploads Keyword.get(unquote(opts), :uploads, [])

      on_mount({Alva.LiveView, %{streams: @alva_streams, uploads: @alva_uploads}})
    end
  end

  def on_mount(config, params, _session, socket) do
    streams_config = Map.get(config, :streams, [])
    uploads_config = Map.get(config, :uploads, [])
    socket = Phoenix.LiveView.put_private(socket, :alva_options, streams: streams_config)

    otp_app = host_app_otp_app!(socket)
    registry = Alva.Registry.registry(otp_app)

    socket
    |> setup_initial_alva_state(otp_app, registry)
    |> configure_streams(streams_config, params, otp_app)
    |> configure_file_uploads(uploads_config, otp_app)
    |> attach_alva_hooks(otp_app)
    |> then(&{:cont, &1})
  end

  defp setup_initial_alva_state(socket, otp_app, registry) do
    update_alva(socket, fn state ->
      state
      |> Map.merge(projection_cache(registry))
      |> Map.merge(%{
        otp_app: otp_app,
        domains: registry.domains
      })
    end)
  end

  def reconfigure_streams(socket, params \\ %{}) do
    state = alva_state(socket)

    Enum.reduce(state.streams || %{}, socket, fn {name, stream_meta}, acc_socket ->
      config = [
        resource: stream_meta.resource,
        source: stream_meta.source,
        scope: Map.get(stream_meta, :scope, %{}),
        sync_on: stream_meta.sync_on
      ]

      configure_stream(acc_socket, name, config, params, state.otp_app)
    end)
  end

  defp configure_streams(socket, streams_config, params, otp_app) do
    Enum.reduce(streams_config, socket, fn {name, config}, acc_socket ->
      configure_stream(acc_socket, name, config, params, otp_app)
    end)
  end

  defp configure_stream(socket, name, config, params, _otp_app) do
    resource = Keyword.fetch!(config, :resource)
    source = Keyword.fetch!(config, :source)
    scope_def = Keyword.get(config, :scope, %{})
    sync_on = Keyword.get(config, :sync_on, [])

    scope_args =
      Map.new(scope_def, fn {arg_name, assign_key} ->
        value = Map.get(socket.assigns, assign_key) || Map.get(params, to_string(assign_key))
        {arg_name, value}
      end)

    socket
    |> load_stream_data(name, resource, source, scope_args)
    |> setup_stream_pubsub(resource, sync_on, scope_args)
    |> register_stream_meta(name, resource, source, scope_def, scope_args, sync_on)
  end

  defp load_stream_data(socket, name, resource, source, scope_args) do
    {actor, tenant} = socket_actor_tenant(socket)

    query =
      resource
      |> Ash.Query.new()
      |> Ash.Query.for_read(source, scope_args, actor: actor, tenant: tenant)

    records =
      case Ash.read(query, actor: actor, tenant: tenant) do
        {:ok, results} -> results
        {:error, _} -> []
      end

    Phoenix.LiveView.stream(socket, name, records)
  end

  defp setup_stream_pubsub(socket, resource, sync_on, scope_args) do
    if Ash.Resource.Info.notifiers(resource) |> Enum.member?(Ash.Notifier.PubSub) do
      subscribe_to_pubsub_topics(socket, resource, sync_on, scope_args)
    else
      socket
    end
  end

  defp register_stream_meta(socket, name, resource, source, scope_def, scope_args, sync_on) do
    update_alva(socket, fn state ->
      streams_meta = Map.get(state, :streams, %{})

      new_meta = %{
        resource: resource,
        source: source,
        scope: scope_def,
        scope_args: scope_args,
        sync_on: sync_on
      }

      Map.put(state, :streams, Map.put(streams_meta, name, new_meta))
    end)
  end

  defp configure_file_uploads(socket, uploads, otp_app) do
    upload_arg_names =
      Enum.flat_map(uploads || [], fn upload_name ->
        fetch_upload_args(upload_name, otp_app)
      end)
      |> Enum.uniq()

    Enum.reduce(upload_arg_names, socket, fn arg_name, acc_socket ->
      Phoenix.LiveView.allow_upload(acc_socket, arg_name, accept: :any, auto_upload: true)
    end)
  end

  defp fetch_upload_args(upload_name, otp_app) do
    case Alva.Registry.fetch_event(otp_app, to_string(upload_name)) do
      {:ok, resource, event_def} ->
        case Ash.Resource.Info.action(resource, event_def.action) do
          nil -> []
          action -> extract_file_args(action.arguments)
        end

      _ ->
        []
    end
  end

  defp extract_file_args(arguments) do
    arguments
    |> Enum.filter(fn arg ->
      case arg.type do
        Ash.Type.File -> true
        {:array, Ash.Type.File} -> true
        _ -> false
      end
    end)
    |> Enum.map(& &1.name)
  end

  defp attach_alva_hooks(socket, otp_app) do
    socket
    |> attach_event_hook(otp_app)
    |> attach_info_hook()
  end

  defp attach_event_hook(socket, otp_app) do
    Phoenix.LiveView.attach_hook(socket, :alva_handle_event, :handle_event, fn event_name,
                                                                               params,
                                                                               sock ->
      cond do
        upload_lifecycle_event?(event_name) ->
          {:halt, sock}

        event_name == "alva:subscribe_signal" ->
          handle_subscribe_signal(params, sock, otp_app)

        event_name == "alva:unsubscribe_signal" ->
          handle_unsubscribe_signal(params, sock, otp_app)

        true ->
          res = Alva.Dispatcher.dispatch(event_name, params, otp_app: otp_app, socket: sock)
          handle_dispatch_result(res, sock)
      end
    end)
  end

  defp handle_dispatch_result(%{ok: false, error: %{type: "unknown"}}, sock) do
    {:cont, sock}
  end

  defp handle_dispatch_result(res, sock) do
    {:halt, res, sock}
  end

  defp attach_info_hook(socket) do
    Phoenix.LiveView.attach_hook(socket, :alva_handle_info, :handle_info, fn
      %Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{} = notification} = broadcast,
      sock ->
        _ = broadcast
        handle_notification(notification, sock, notification_occurrence_keys(notification))

      _msg, sock ->
        {:cont, sock}
    end)
  end

  defp handle_notification(notification, sock, occurrence_keys) do
    %{streams: streams, signals: signals} =
      matching_projection_operations(sock, notification.resource, occurrence_keys)

    if streams == [] and signals == [] do
      {:cont, sock}
    else
      sock = apply_stream_operations(sock, streams, notification.data)

      if signals == [] do
        {:halt, sock}
      else
        {:halt, push_signals(sock, notification.data, signals)}
      end
    end
  end

  defp apply_stream_operations(socket, streams, data) do
    Enum.reduce(streams, socket, fn {name, operation}, acc_socket ->
      apply_stream_operation(acc_socket, name, operation, data)
    end)
  end

  defp apply_stream_operation(socket, name, %{op: :delete}, data) do
    Phoenix.LiveView.stream_delete(socket, name, Alva.Serializer.strip_metadata(data))
  end

  defp apply_stream_operation(socket, name, %{op: :update} = operation, data) do
    if record_in_scope?(socket, operation.meta, data) do
      Phoenix.LiveView.stream_insert(
        socket,
        name,
        Alva.Serializer.strip_metadata(data),
        stream_operation_opts(operation, update_only: true)
      )
    else
      Phoenix.LiveView.stream_delete(socket, name, Alva.Serializer.strip_metadata(data))
    end
  end

  defp apply_stream_operation(socket, name, %{op: :insert} = operation, data) do
    item = Alva.Serializer.strip_metadata(data)

    if pending_stream_insert?(socket, name, item) do
      socket
    else
      Phoenix.LiveView.stream_insert(socket, name, item, stream_operation_opts(operation))
    end
  end

  defp pending_stream_insert?(socket, name, %{id: id}) do
    dom_id = "#{name}-#{id}"

    socket.assigns
    |> Map.get(:streams, %{})
    |> Map.get(name, %{})
    |> Map.get(:inserts, [])
    |> Enum.any?(fn
      {^dom_id, _at, _item, _limit, _update_only} -> true
      _ -> false
    end)
  end

  defp pending_stream_insert?(_socket, _name, _item), do: false

  defp stream_operation_opts(operation, defaults \\ []) do
    defaults
    |> Keyword.merge(
      operation
      |> Map.take([:at, :limit, :update_only])
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    )
  end

  defp upload_lifecycle_event?(event_name)
       when event_name in [@upload_change_event, @upload_submit_event],
       do: true

  defp upload_lifecycle_event?(_event_name), do: false

  defp subscribe_to_pubsub_topics(socket, resource, sync_on, scope_args) do
    topics = pubsub_topics(resource, sync_on, scope_args)
    pubsub = endpoint_pubsub!(socket)
    Enum.each(topics, &Phoenix.PubSub.subscribe(pubsub, &1))
    socket
  end

  defp endpoint_pubsub!(%{endpoint: endpoint}) when is_atom(endpoint) and not is_nil(endpoint) do
    endpoint.config(:pubsub_server) ||
      raise ArgumentError,
            "Alva.LiveView realtime subscription transport requires a socket endpoint with :pubsub_server"
  end

  defp endpoint_pubsub!(_socket) do
    raise ArgumentError,
          "Alva.LiveView realtime subscription transport requires socket.endpoint to be set"
  end

  defp host_app_otp_app!(socket) do
    case Alva.Registry.otp_app(socket) do
      otp_app when is_atom(otp_app) and not is_nil(otp_app) ->
        otp_app

      _ ->
        raise ArgumentError,
              "Alva.LiveView requires socket.endpoint to resolve the consuming host app registry. Page-scoped `domains:` activation is no longer supported."
    end
  end

  defp push_signals(socket, data, signals) do
    Enum.reduce(signals, socket, fn {_key, signal}, acc_socket ->
      Phoenix.LiveView.push_event(acc_socket, signal.name, signal_payload(data, signal))
    end)
  end

  defp signal_payload(data, signal) do
    {payload, meta} = Alva.Serializer.serialize(data, expose_metadata: signal.expose_metadata)

    if map_size(meta) == 0 do
      payload
    else
      Map.put(payload, :meta, meta)
    end
  end

  defp matching_projection_operations(socket, notification_resource, occurrence_keys) do
    state = alva_state(socket)

    streams = Map.get(state, :streams, %{})

    stream_ops =
      streams
      |> Enum.filter(fn {_name, meta} -> meta.resource == notification_resource end)
      |> Enum.flat_map(fn {stream_name, stream_meta} ->
        occurrence_keys
        |> Enum.filter(&(&1 in stream_meta.sync_on))
        |> Enum.map(fn action_name ->
          action = Ash.Resource.Info.action(stream_meta.resource, action_name)
          op_type = action_type_to_op(action && action.type)
          {stream_name, %{op: op_type, meta: stream_meta}}
        end)
      end)

    active_signals = Map.get(state, :active_signals, %{})

    signal_ops =
      active_signals
      |> Enum.filter(fn {_name, meta} ->
        meta.resource == notification_resource and
          Enum.any?(occurrence_keys, &(&1 in meta.signal.on))
      end)
      |> Enum.map(fn {signal_name, meta} -> {signal_name, meta.signal} end)

    %{streams: stream_ops, signals: signal_ops}
  end

  defp handle_subscribe_signal(params, sock, otp_app) do
    signal_name = params["name"]
    payload = params["input"] || %{}

    case authorize_signal_subscription(sock, otp_app, signal_name, payload) do
      {:ok, resource, signal} ->
        sock = do_subscribe_signal(sock, signal_name, resource, signal, payload)
        {:halt, %{ok: true}, sock}

      {:error, reason, message} ->
        {:halt, %{ok: false, error: %{type: reason, message: message}}, sock}
    end
  end

  defp authorize_signal_subscription(sock, otp_app, signal_name, payload) do
    with {:ok, resource, signal} <- Alva.Registry.fetch_signal(otp_app, signal_name),
         {actor, tenant} <- socket_actor_tenant(sock),
         action when not is_nil(action) <-
           Ash.Resource.Info.action(resource, signal.authorize_with),
         subject <- build_authorization_subject(resource, action, payload),
         true <- Ash.can?(subject, actor, tenant: tenant, maybe_is: false) do
      {:ok, resource, signal}
    else
      :error ->
        {:error, "not_found", "Signal not found"}

      nil ->
        {:error, "not_found", "Signal authorize_with action not found"}

      false ->
        {:error, "forbidden", "Forbidden"}
    end
  end

  defp do_subscribe_signal(sock, signal_name, resource, signal, payload) do
    topics = pubsub_topics(resource, signal.on, payload)

    state = alva_state(sock)
    active_signals = Map.get(state, :active_signals, %{})

    sock =
      if Map.has_key?(active_signals, signal_name) do
        {:halt, _reply, sock} = handle_unsubscribe_signal(%{"name" => signal_name}, sock, nil)
        sock
      else
        sock
      end

    maybe_subscribe_to_topics(sock, topics)

    update_alva(sock, fn state ->
      active_signals = Map.get(state, :active_signals, %{})
      signal_meta = %{resource: resource, signal: signal, topics: topics, params: payload}
      Map.put(state, :active_signals, Map.put(active_signals, signal_name, signal_meta))
    end)
  end

  defp build_authorization_subject(resource, action, payload) do
    case action.type do
      :read -> Ash.Query.for_read(resource, action.name, payload)
      :create -> Ash.Changeset.for_create(resource, action.name, payload)
      :update -> Ash.Changeset.for_update(resource, action.name, payload)
      :destroy -> Ash.Changeset.for_destroy(resource, action.name, payload)
      :action -> Ash.ActionInput.for_action(resource, action.name, payload)
    end
  end

  defp all_active_topics(active_signals) do
    Enum.flat_map(active_signals, fn {_, meta} -> Map.get(meta, :topics, []) end) |> MapSet.new()
  end

  defp maybe_subscribe_to_topics(sock, topics) do
    if Phoenix.LiveView.connected?(sock) do
      state = alva_state(sock)
      active_signals = Map.get(state, :active_signals, %{})
      signal_topics = all_active_topics(active_signals)
      stream_topics = all_stream_topics(state)
      existing_topics = MapSet.union(signal_topics, stream_topics)

      pubsub = endpoint_pubsub!(sock)

      topics
      |> Enum.reject(&MapSet.member?(existing_topics, &1))
      |> Enum.each(&Phoenix.PubSub.subscribe(pubsub, &1))
    end
  end

  defp all_stream_topics(state) do
    streams = Map.get(state, :streams, %{})

    streams
    |> Enum.flat_map(fn {_name, meta} ->
      pubsub_topics(meta.resource, meta.sync_on, Map.get(meta, :scope_args, %{}))
    end)
    |> MapSet.new()
  end

  defp handle_unsubscribe_signal(params, sock, _otp_app) do
    signal_name = params["name"]
    state = alva_state(sock)
    active_signals = Map.get(state, :active_signals, %{})
    topics_to_remove = Map.get(active_signals, signal_name, %{}) |> Map.get(:topics, [])

    active_signals = Map.delete(active_signals, signal_name)

    sock =
      update_alva(sock, fn state ->
        Map.put(state, :active_signals, active_signals)
      end)

    if Phoenix.LiveView.connected?(sock) do
      remaining_signal_topics = all_active_topics(active_signals)
      stream_topics = all_stream_topics(alva_state(sock))
      protected_topics = MapSet.union(remaining_signal_topics, stream_topics)
      pubsub = endpoint_pubsub!(sock)

      topics_to_remove
      |> Enum.reject(&MapSet.member?(protected_topics, &1))
      |> Enum.each(&Phoenix.PubSub.unsubscribe(pubsub, &1))
    end

    {:halt, %{ok: true}, sock}
  end

  defp projection_cache(%Alva.Registry{} = registry) do
    %{
      event_map: registry.event_map
    }
  end

  defp validate_use_opts!(opts, caller) when is_list(opts) do
    if Keyword.keyword?(opts) do
      Enum.each(Keyword.keys(opts), &validate_public_activation_key!(&1, caller))

      case Keyword.fetch(opts, :streams) do
        {:ok, streams} -> maybe_validate_stream_use_declarations!(streams, caller)
        :error -> :ok
      end
    else
      raise_compile_error!(caller, @err_opts_expected)
    end
  end

  defp validate_use_opts!(_opts, caller) do
    raise_compile_error!(caller, @err_opts_expected)
  end

  defp maybe_validate_stream_use_declarations!(streams, caller) do
    case expand_use_opt_literal(streams, caller) do
      {:ok, streams} -> validate_stream_use_declarations!(streams, caller)
      :dynamic -> :ok
    end
  end

  defp expand_use_opt_literal(value, caller) do
    expanded = Macro.expand(value, caller)

    if Macro.quoted_literal?(expanded) do
      {:ok, expanded}
    else
      :dynamic
    end
  end

  defp validate_public_activation_key!(:domains, caller) do
    raise_compile_error!(caller, @err_domains_removed)
  end

  defp validate_public_activation_key!(:subscriptions, caller) do
    raise_compile_error!(
      caller,
      "The legacy `subscriptions:` DSL is strictly removed. Use `streams:` instead."
    )
  end

  defp validate_public_activation_key!(key, caller)
       when key in [:collections, :signals, :route_subscriptions, :page_events, :page_state] do
    raise_compile_error!(
      caller,
      "Alva declarative page activation no longer accepts `#{key}:`. For the supported V2 path, use `streams:` and `uploads:`."
    )
  end

  defp validate_public_activation_key!(key, caller) do
    unless key in @public_activation_keys do
      raise_compile_error!(caller, err_unsupported_key(key))
    end
  end

  defp validate_stream_use_declarations!(streams, caller)
       when is_list(streams) do
    keys =
      Enum.map(streams, fn
        key when is_atom(key) ->
          key

        {key, opts} when is_atom(key) and is_list(opts) ->
          validate_stream_use_opts!(key, opts, caller)
          key

        name when is_binary(name) ->
          raise_compile_error!(
            caller,
            "Alva declarative `streams:` entries must use declaration key atoms, got browser-facing name #{inspect(name)}"
          )

        {key, _opts} ->
          raise_compile_error!(
            caller,
            invalid_stream_use_entries_description("Invalid key: #{inspect(key)}")
          )

        other ->
          raise_compile_error!(
            caller,
            invalid_stream_use_entries_description("Got: #{inspect(other)}")
          )
      end)

    validate_unique_activation_names!(keys, :stream, caller)
    keys
  end

  defp validate_stream_use_declarations!(_streams, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative `streams:` must be a list of declaration key atoms or keyword entries."
    )
  end

  defp validate_stream_use_opts!(name, opts, caller) when is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise_compile_error!(caller, invalid_stream_use_opts_description(name))
    end
  end

  defp validate_stream_use_opts!(name, _opts, caller) do
    raise_compile_error!(caller, invalid_stream_use_opts_description(name))
  end

  defp validate_unique_activation_names!(names, kind, caller) do
    names
    |> Enum.frequencies()
    |> Enum.each(fn
      {_name, 1} ->
        :ok

      {name, _count} ->
        raise_compile_error!(
          caller,
          "Alva declarative #{kind} activation contains duplicate entries for #{inspect(name)}."
        )
    end)
  end

  defp invalid_stream_use_entries_description(detail) do
    "Alva declarative `streams:` entries must be atoms or keyword entries like `streams: [sales_orders: [resource: App.Order, source: :list]]`. #{detail}"
  end

  defp invalid_stream_use_opts_description(name) do
    "Alva declarative stream #{inspect(name)} options must be a keyword list containing :resource, :source, etc."
  end

  defp raise_compile_error!(caller, description) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description: description
  end

  defp notification_occurrence_keys(%Ash.Notifier.Notification{
         resource: resource,
         action: %{name: action_name}
       })
       when is_atom(resource) and is_atom(action_name) do
    action_occurrence_keys(resource, action_name)
  end

  defp notification_occurrence_keys(%Ash.Notifier.Notification{
         resource: resource,
         action: action_name
       })
       when is_atom(resource) and is_atom(action_name) do
    action_occurrence_keys(resource, action_name)
  end

  defp notification_occurrence_keys(%Ash.Notifier.Notification{action: action})
       when is_map_key(action, :name) do
    MapSet.new([action.name])
  end

  defp notification_occurrence_keys(%Ash.Notifier.Notification{action: action_name})
       when is_atom(action_name),
       do: MapSet.new([action_name])

  defp notification_occurrence_keys(_notification), do: MapSet.new()

  defp action_occurrence_keys(resource, action_name) when is_atom(resource) do
    case Ash.Resource.Info.action(resource, action_name) do
      nil ->
        MapSet.new([action_name])

      action ->
        publication_occurrence_keys(resource, action)
    end
  end

  defp publication_occurrence_keys(resource, action) do
    resource
    |> Ash.Notifier.PubSub.Info.publications()
    |> Enum.filter(&publication_matches?(&1, action))
    |> Enum.map(&publication_occurrence_key/1)
    |> case do
      [] -> [action.name]
      occurrence_keys -> occurrence_keys
    end
    |> MapSet.new()
  end

  defp publication_matches?(%{action: action}, %{name: action}) when not is_nil(action), do: true

  defp publication_matches?(%{type: type, except: except}, %{type: type, name: name})
       when not is_nil(type) do
    name not in List.wrap(except)
  end

  defp publication_matches?(_publication, _action), do: false

  defp record_in_scope?(socket, stream_meta, record) do
    resource = stream_meta.resource
    primary_keys = Ash.Resource.Info.primary_key(resource)
    filter_args = Map.take(record, primary_keys) |> Map.to_list()
    {actor, tenant} = socket_actor_tenant(socket)

    query =
      resource
      |> Ash.Query.for_read(stream_meta.source, stream_meta.scope_args)
      |> Ash.Query.filter_input(filter_args)

    case Ash.read(query, tenant: tenant, actor: actor) do
      {:ok, []} -> false
      {:ok, _} -> true
      _ -> false
    end
  end

  defp pubsub_topics(resource, actions, payload) do
    prefix = Ash.Notifier.PubSub.Info.prefix(resource) || ""
    delimiter = Ash.Notifier.PubSub.Info.delimiter(resource)

    Ash.Notifier.PubSub.Info.publications(resource)
    |> Enum.filter(&(&1.action in actions))
    |> Enum.map(fn pub ->
      topic_parts =
        Enum.map(pub.topic, fn
          part when is_atom(part) ->
            Map.get(payload, to_string(part)) || Map.get(payload, part) || to_string(part)

          part ->
            part
        end)

      topic_suffix = Enum.join(topic_parts, delimiter)
      if prefix == "", do: topic_suffix, else: "#{prefix}#{delimiter}#{topic_suffix}"
    end)
    |> Enum.uniq()
  end

  defp action_type_to_op(:destroy), do: :delete
  defp action_type_to_op(:create), do: :insert
  defp action_type_to_op(_), do: :update

  defp publication_occurrence_key(%{action: action}) when not is_nil(action), do: action
  defp publication_occurrence_key(%{type: type}) when not is_nil(type), do: type
  defp publication_occurrence_key(_publication), do: nil

  defp socket_actor_tenant(socket) do
    actor = socket.assigns[:current_user] || socket.assigns[:current_actor]
    tenant = socket.assigns[:current_tenant]
    {actor, tenant}
  end

  defp update_alva(socket, fun) do
    state =
      socket
      |> alva_state()
      |> fun.()

    put_in(socket.private[@alva_private_key], state)
  end

  defp alva_state(socket) do
    Map.get(socket.private, @alva_private_key, %{
      otp_app: nil,
      domains: [],
      event_map: %{}
    })
  end
end
