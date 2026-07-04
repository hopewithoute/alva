defmodule Alva.LiveView do
  @moduledoc """
  A macro to inject Alva-specific functionality into Phoenix LiveViews.
  """

  @alva_private_key :alva

  defmacro __using__(opts) do
    quote do
      import Alva.LiveView
      @alva_domains Keyword.get(unquote(opts), :domains, [])
      @alva_collections Keyword.get(unquote(opts), :collections, [])
      on_mount({Alva.LiveView, {@alva_domains, @alva_collections}})
    end
  end

  def subscribe(socket, topic, opts \\ []) when is_binary(topic) do
    pubsub = Keyword.get(opts, :pubsub) || endpoint_pubsub!(socket)

    :ok = Phoenix.PubSub.subscribe(pubsub, topic)

    update_alva(socket, fn state ->
      update_in(state.route_subscriptions, &MapSet.put(&1, topic))
    end)
  end

  def activate_stream(socket, name) when is_atom(name) do
    ensure_projection!(socket, :stream, name)

    update_alva(socket, fn state ->
      update_in(state.streams, &MapSet.put(&1, name))
    end)
  end

  def collection(socket, name, opts \\ [])

  def collection(socket, name, opts) when is_atom(name) and is_list(opts) do
    {_resource, collection} = find_projection!(socket, :collection, name)
    params = collection_params!(socket, name, Keyword.get(opts, :params, %{}))

    result =
      Alva.Dispatcher.dispatch(collection.source.event, params,
        domains: alva_state(socket).domains,
        socket: socket
      )

    case result do
      %{ok: true, data: data} ->
        socket
        |> Phoenix.LiveView.stream(name, stream_query_items(data),
          reset: collection.source.mode == :reset
        )
        |> subscribe_collection_topics(name, Keyword.get(opts, :subscriptions, []))
        |> update_alva(fn state ->
          update_in(state.collections, &MapSet.put(&1, name))
        end)

      %{ok: false, error: error} ->
        raise ArgumentError,
              "Alva collection #{inspect(name)} source event #{inspect(collection.source.event)} failed: #{inspect(error)}"
    end
  end

  def activate_signal(socket, name) when is_binary(name) do
    ensure_projection!(socket, :signal, name)

    update_alva(socket, fn state ->
      update_in(state.signals, &MapSet.put(&1, name))
    end)
  end

  def bind_stream_query(socket, event_name, stream_name, opts \\ [])
      when is_binary(event_name) and is_atom(stream_name) do
    ensure_projection!(socket, :stream, stream_name)

    binding = %{
      stream: stream_name,
      mode: Keyword.get(opts, :mode, :append),
      limit: Keyword.get(opts, :limit)
    }

    unless binding.mode in [:append, :prepend, :reset] do
      raise ArgumentError,
            "Unknown Alva stream query mode #{inspect(binding.mode)} for event #{inspect(event_name)}"
    end

    update_alva(socket, fn state ->
      update_in(state.stream_queries, &Map.put(&1, event_name, binding))
    end)
  end

  def route_subscriptions(socket) do
    socket
    |> alva_state()
    |> Map.fetch!(:route_subscriptions)
    |> MapSet.to_list()
  end

  def projection_active?(socket, :stream, name) do
    socket
    |> alva_state()
    |> Map.fetch!(:streams)
    |> MapSet.member?(name)
  end

  def projection_active?(socket, :collection, name) do
    socket
    |> alva_state()
    |> Map.fetch!(:collections)
    |> MapSet.member?(name)
  end

  def projection_active?(socket, :signal, name) do
    socket
    |> alva_state()
    |> Map.fetch!(:signals)
    |> MapSet.member?(name)
  end

  def active_projections(socket, %Ash.Notifier.Notification{} = notification) do
    active_projections(socket, notification, notification_events(notification))
  end

  def active_projections(
        socket,
        %Phoenix.Socket.Broadcast{
          event: event,
          payload: %Ash.Notifier.Notification{} = notification
        }
      ) do
    active_projections(socket, notification, MapSet.new([to_string(event)]))
  end

  defp active_projections(
         socket,
         %Ash.Notifier.Notification{resource: notification_resource},
         events
       ) do
    %{
      streams:
        socket
        |> active_stream_projections()
        |> Enum.filter(&stream_projection_matches?(&1, notification_resource, events))
        |> Enum.map(fn {name, _projection} -> name end),
      signals:
        socket
        |> active_signal_projections()
        |> Enum.filter(fn {_name, {resource, signal}} ->
          resource == notification_resource and MapSet.member?(events, signal.on)
        end)
        |> Enum.map(fn {name, _projection} -> name end)
    }
  end

  def on_mount(config, _params, _session, socket) do
    {domains, collections} = normalize_mount_config(config)

    socket =
      update_alva(socket, fn state ->
        %{state | domains: domains}
      end)

    # Configure file uploads
    socket =
      Enum.reduce(domains, socket, fn domain, acc_socket ->
        domain
        |> Alva.Domain.Info.file_upload_arguments()
        |> Enum.reduce(acc_socket, fn arg, s ->
          Phoenix.LiveView.allow_upload(s, arg.name, accept: :any, auto_upload: true)
        end)
      end)

    # Attach handle_event hook
    socket =
      Phoenix.LiveView.attach_hook(socket, :alva_handle_event, :handle_event, fn event_name,
                                                                                 params,
                                                                                 sock ->
        res = Alva.Dispatcher.dispatch(event_name, params, domains: domains, socket: sock)

        case res do
          %{ok: false, error: %{type: "unknown"}} ->
            {:cont, sock}

          _ ->
            sock =
              sock
              |> apply_stream_query(event_name, res)
              |> apply_event_stream_operations(event_name, res)

            {:halt, res, sock}
        end
      end)

    # Attach handle_info hook
    socket =
      Phoenix.LiveView.attach_hook(socket, :alva_handle_info, :handle_info, fn
        %Ash.Notifier.Notification{} = notification, sock ->
          handle_notification(notification, sock, notification_events(notification))

        %Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{} = notification} =
            broadcast,
        sock ->
          handle_notification(notification, sock, broadcast_events(broadcast))

        _msg, sock ->
          {:cont, sock}
      end)

    socket =
      Enum.reduce(collections, socket, fn collection_spec, acc_socket ->
        {collection_name, opts} = normalize_collection_spec!(collection_spec)
        collection(acc_socket, collection_name, opts)
      end)

    {:cont, socket}
  end

  defp handle_notification(notification, sock, events) do
    projections = active_projections(sock, notification, events)

    case projections do
      %{streams: [], signals: []} ->
        {:cont, sock}

      %{signals: signals} ->
        sock = apply_stream_operations(sock, notification, events)

        if signals == [] do
          {:halt, sock}
        else
          {:halt, push_signals(sock, notification, events)}
        end
    end
  end

  defp endpoint_pubsub!(%{endpoint: endpoint}) when is_atom(endpoint) and not is_nil(endpoint) do
    endpoint.config(:pubsub_server) ||
      raise ArgumentError,
            "Alva.LiveView.subscribe/3 requires :pubsub when socket endpoint has no :pubsub_server"
  end

  defp endpoint_pubsub!(_socket) do
    raise ArgumentError,
          "Alva.LiveView.subscribe/3 requires :pubsub when socket has no endpoint"
  end

  defp active_stream_projections(socket) do
    state = alva_state(socket)

    state.domains
    |> Enum.flat_map(&Alva.Domain.Info.alva_stream_map/1)
    |> Enum.filter(fn {name, _projection} -> MapSet.member?(state.streams, name) end)
  end

  defp active_signal_projections(socket) do
    state = alva_state(socket)

    state.domains
    |> Enum.flat_map(&Alva.Domain.Info.alva_signal_map/1)
    |> Enum.filter(fn {name, _projection} -> MapSet.member?(state.signals, name) end)
  end

  defp apply_stream_query(socket, event_name, %{ok: true, data: data}) do
    state = alva_state(socket)

    case Map.fetch(state.stream_queries, event_name) do
      {:ok, %{stream: stream_name} = binding} ->
        if MapSet.member?(state.streams, stream_name) do
          apply_stream_query_binding(socket, binding, data)
        else
          socket
        end

      :error ->
        socket
    end
  end

  defp apply_stream_query(socket, _event_name, _result), do: socket

  defp apply_event_stream_operations(socket, event_name, %{ok: true, data: data}) do
    state = alva_state(socket)

    event_projection =
      state.domains
      |> Enum.find_value(fn domain ->
        domain
        |> Alva.Domain.Info.alva_event_map()
        |> Map.get(event_name)
      end)

    case event_projection do
      {resource, %{action: action_name}} ->
        apply_stream_operations(socket, resource, to_string(action_name), data)

      _ ->
        socket
    end
  end

  defp apply_event_stream_operations(socket, _event_name, _result), do: socket

  defp apply_stream_query_binding(socket, %{stream: stream_name, mode: :reset}, data) do
    Phoenix.Component.assign(socket, stream_name, stream_query_items(data))
  end

  defp apply_stream_query_binding(socket, binding, data) do
    data
    |> stream_query_items()
    |> Enum.reduce(socket, fn item, acc_socket ->
      Phoenix.Component.update(acc_socket, binding.stream, fn current ->
        current = current || []

        if binding.mode == :prepend do
          [item | current]
        else
          current ++ [item]
        end
      end)
    end)
  end

  defp stream_query_items(nil), do: []
  defp stream_query_items(items) when is_list(items), do: items
  defp stream_query_items(item), do: [item]

  defp collection_params!(_socket, _name, params) when is_map(params), do: params

  defp collection_params!(socket, name, callback) when is_atom(callback) do
    callback
    |> resolve_live_view_callback!(socket, name, :params)
    |> unwrap_callback_result!(name, :params, callback)
    |> case do
      params when is_map(params) ->
        params

      params ->
        raise ArgumentError,
              "Alva collection #{inspect(name)} params callback #{inspect(callback)} must return a map, got: #{inspect(params)}"
    end
  end

  defp collection_params!(_socket, name, params) do
    raise ArgumentError,
          "Alva collection #{inspect(name)} params must be a map or local callback name, got: #{inspect(params)}"
  end

  defp subscribe_collection_topics(socket, name, subscriptions) do
    topics =
      subscriptions
      |> List.wrap()
      |> Enum.flat_map(&collection_subscription_topics!(socket, name, &1))

    if Phoenix.LiveView.connected?(socket) do
      Enum.reduce(topics, socket, fn topic, acc_socket ->
        subscribe(acc_socket, topic)
      end)
    else
      socket
    end
  end

  defp collection_subscription_topics!(_socket, _name, topic) when is_binary(topic), do: [topic]

  defp collection_subscription_topics!(socket, name, callback) when is_atom(callback) do
    callback
    |> resolve_live_view_callback!(socket, name, :subscription)
    |> unwrap_callback_result!(name, :subscription, callback)
    |> normalize_subscription_topics!(name, callback)
  end

  defp collection_subscription_topics!(_socket, name, topic) do
    raise ArgumentError,
          "Alva collection #{inspect(name)} subscriptions must be binary topics or local callback names, got: #{inspect(topic)}"
  end

  defp normalize_subscription_topics!(topic, _name, _callback) when is_binary(topic), do: [topic]

  defp normalize_subscription_topics!(topics, name, callback) when is_list(topics) do
    if Enum.all?(topics, &is_binary/1) do
      topics
    else
      raise_invalid_subscription_callback!(name, callback, topics)
    end
  end

  defp normalize_subscription_topics!(topics, name, callback) do
    raise_invalid_subscription_callback!(name, callback, topics)
  end

  defp raise_invalid_subscription_callback!(name, callback, topics) do
    raise ArgumentError,
          "Alva collection #{inspect(name)} subscription callback #{inspect(callback)} must return a binary topic or list of binary topics, got: #{inspect(topics)}"
  end

  defp resolve_live_view_callback!(callback, %{view: view} = socket, name, kind)
       when is_atom(view) and not is_nil(view) do
    cond do
      function_exported?(view, callback, 1) ->
        apply(view, callback, [socket])

      function_exported?(view, callback, 0) ->
        apply(view, callback, [])

      true ->
        raise ArgumentError,
              "Alva collection #{inspect(name)} #{kind} callback #{inspect(callback)} is not defined on #{inspect(view)}"
    end
  end

  defp resolve_live_view_callback!(callback, _socket, name, kind) do
    raise ArgumentError,
          "Alva collection #{inspect(name)} #{kind} callback #{inspect(callback)} requires socket.view to be set"
  end

  defp unwrap_callback_result!({:ok, value}, _name, _kind, _callback), do: value

  defp unwrap_callback_result!({:error, reason}, name, kind, callback) do
    raise ArgumentError,
          "Alva collection #{inspect(name)} #{kind} callback #{inspect(callback)} failed: #{inspect(reason)}"
  end

  defp unwrap_callback_result!(value, _name, _kind, _callback), do: value

  defp push_signals(
         socket,
         %Ash.Notifier.Notification{resource: notification_resource, data: data},
         events
       ) do
    socket
    |> active_signal_projections()
    |> Enum.filter(fn {_name, {resource, signal}} ->
      resource == notification_resource and MapSet.member?(events, signal.on)
    end)
    |> Enum.reduce(socket, fn {name, {_resource, signal}}, acc_socket ->
      Phoenix.LiveView.push_event(acc_socket, name, signal_payload(data, signal))
    end)
  end

  defp signal_payload(data, signal) do
    {payload, meta} = Alva.Dispatcher.strip_and_extract_metadata(data, signal)

    if map_size(meta) == 0 do
      normalize_signal_payload(payload)
    else
      put_signal_meta(payload, meta)
    end
  end

  defp normalize_signal_payload(nil), do: %{}
  defp normalize_signal_payload(payload) when is_map(payload), do: payload
  defp normalize_signal_payload(payload), do: %{data: payload}

  defp put_signal_meta(payload, meta) when is_map(payload), do: Map.put(payload, :meta, meta)
  defp put_signal_meta(payload, meta), do: %{data: payload, meta: meta}

  defp apply_stream_operations(
         socket,
         %Ash.Notifier.Notification{resource: notification_resource, data: data},
         events
       ) do
    apply_stream_operations(socket, notification_resource, events, data)
  end

  defp apply_stream_operations(socket, notification_resource, event, data)
       when is_binary(event) do
    apply_stream_operations(socket, notification_resource, MapSet.new([event]), data)
  end

  defp apply_stream_operations(socket, notification_resource, events, data) do
    socket
    |> active_stream_projections()
    |> Enum.flat_map(fn {name, {resource, stream}} ->
      if resource == notification_resource do
        stream.operations
        |> Enum.filter(&MapSet.member?(events, &1.on))
        |> Enum.map(&{name, &1.op})
      else
        []
      end
    end)
    |> Enum.reduce(socket, fn
      {name, :insert}, acc_socket ->
        Phoenix.Component.update(acc_socket, name, fn current ->
          current = current || []
          stripped_data = Alva.Dispatcher.strip_metadata(data)
          upsert_item(current, stripped_data)
        end)

      {name, :update}, acc_socket ->
        Phoenix.Component.update(acc_socket, name, fn current ->
          current = current || []
          stripped_data = Alva.Dispatcher.strip_metadata(data)

          upsert_item(current, stripped_data)
        end)

      {name, :delete}, acc_socket ->
        Phoenix.Component.update(acc_socket, name, fn current ->
          current = current || []
          stripped_data = Alva.Dispatcher.strip_metadata(data)
          Enum.reject(current, &(&1.id == stripped_data.id))
        end)
    end)
  end

  defp upsert_item(current, %{id: id} = item) do
    if Enum.any?(current, &match?(%{id: ^id}, &1)) do
      Enum.map(current, fn
        %{id: ^id} -> item
        existing -> existing
      end)
    else
      current ++ [item]
    end
  end

  defp upsert_item(current, item), do: current ++ [item]

  defp stream_projection_matches?(
         {_name, {resource, stream}},
         notification_resource,
         events
       ) do
    resource == notification_resource and
      Enum.any?(stream.operations, &MapSet.member?(events, &1.on))
  end

  defp ensure_projection!(socket, kind, name) do
    find_projection!(socket, kind, name)
    :ok
  end

  defp find_projection!(socket, kind, name) do
    domains = alva_state(socket).domains

    projection =
      Enum.find_value(domains, fn domain ->
        domain
        |> projection_map(kind)
        |> Map.get(name)
      end)

    case projection do
      nil ->
        raise ArgumentError,
              "Unknown Alva #{kind} projection #{inspect(name)} for mounted domains #{inspect(domains)}"

      projection ->
        projection
    end
  end

  defp projection_map(domain, :stream), do: Alva.Domain.Info.alva_stream_map(domain)
  defp projection_map(domain, :collection), do: Alva.Domain.Info.alva_collection_map(domain)
  defp projection_map(domain, :signal), do: Alva.Domain.Info.alva_signal_map(domain)

  defp normalize_mount_config({domains, collections})
       when is_list(domains) and is_list(collections) do
    {domains, collections}
  end

  defp normalize_mount_config(domains) when is_list(domains) do
    {domains, []}
  end

  defp normalize_collection_spec!(name) when is_atom(name), do: {name, []}

  defp normalize_collection_spec!({name, opts}) when is_atom(name) and is_list(opts) do
    {name, opts}
  end

  defp normalize_collection_spec!(spec) do
    raise ArgumentError,
          "Alva collection activation must be an atom name or {name, opts}, got: #{inspect(spec)}"
  end

  defp notification_events(%Ash.Notifier.Notification{resource: resource, action: action})
       when is_atom(resource) and not is_nil(action) do
    resource
    |> Ash.Notifier.PubSub.Info.publications()
    |> Enum.filter(&publication_matches?(&1, action))
    |> Enum.map(&publication_identity/1)
    |> case do
      [] -> [to_string(action.name)]
      events -> events
    end
    |> MapSet.new()
  end

  defp notification_events(%Ash.Notifier.Notification{action: %{name: name}}) do
    MapSet.new([to_string(name)])
  end

  defp notification_events(_notification), do: MapSet.new()

  defp broadcast_events(%Phoenix.Socket.Broadcast{event: event}) do
    MapSet.new([to_string(event)])
  end

  defp publication_matches?(%{action: action}, %{name: action}) when not is_nil(action), do: true

  defp publication_matches?(%{type: type, except: except}, %{type: type, name: name})
       when not is_nil(type) do
    name not in List.wrap(except)
  end

  defp publication_matches?(_publication, _action), do: false

  defp publication_identity(%{event: event}) when not is_nil(event), do: to_string(event)
  defp publication_identity(%{action: action}) when not is_nil(action), do: to_string(action)
  defp publication_identity(%{type: type}), do: to_string(type)

  defp update_alva(socket, fun) do
    state =
      socket
      |> alva_state()
      |> fun.()

    put_in(socket.private[@alva_private_key], state)
  end

  defp alva_state(socket) do
    Map.get(socket.private, @alva_private_key, %{
      domains: [],
      route_subscriptions: MapSet.new(),
      streams: MapSet.new(),
      collections: MapSet.new(),
      signals: MapSet.new(),
      stream_queries: %{}
    })
  end
end
