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
      @alva_streams Keyword.get(unquote(opts), :streams, [])
      @alva_signals Keyword.get(unquote(opts), :signals, [])
      @alva_subscriptions Keyword.get(unquote(opts), :subscriptions, [])
      @alva_route_subscriptions Keyword.get(unquote(opts), :route_subscriptions, [])
      on_mount(
        {Alva.LiveView,
         %{
           domains: @alva_domains,
           collections: @alva_collections,
           streams: @alva_streams,
           signals: @alva_signals,
           subscriptions: @alva_subscriptions,
           route_subscriptions: @alva_route_subscriptions
         }}
      )
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

    socket
    |> assign_stream_if_missing(name)
    |> update_alva(fn state ->
      update_in(state.streams, &MapSet.put(&1, name))
    end)
  end

  def collection(socket, name, opts \\ [])

  def collection(socket, name, opts) when is_atom(name) and is_list(opts) do
    {_resource, collection} = find_projection!(socket, :collection, name)
    source_input = collection_source_input!(socket, name, collection_source_input_option(opts))

    result =
      Alva.Dispatcher.dispatch(collection.source.event, source_input,
        domains: alva_state(socket).domains,
        socket: socket
      )

    case result do
      %{ok: true, data: data} ->
        socket
        |> Phoenix.LiveView.stream(name, collection_source_items!(name, collection, data),
          reset: collection.source.mode == :reset
        )
        |> subscribe_collection_topics(name, Keyword.get(opts, :subscriptions, []))
        |> update_alva(fn state ->
          state
          |> update_in([:collections], &MapSet.put(&1, name))
          |> update_in([:collection_source_inputs], &Map.put(&1, name, source_input))
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

  def reload_collection(socket, name, opts \\ [])

  def reload_collection(socket, name, opts) when is_atom(name) and is_list(opts) do
    ensure_projection!(socket, :collection, name)
    ensure_collection_active!(socket, name)

    source_input =
      if Keyword.has_key?(opts, :source_input) or Keyword.has_key?(opts, :params) do
        collection_source_input!(socket, name, collection_source_input_option(opts))
      else
        active_collection_source_input!(socket, name)
      end

    collection(socket, name, source_input: source_input)
  end

  def route_subscriptions(socket) do
    socket
    |> alva_state()
    |> Map.fetch!(:route_subscriptions)
    |> MapSet.to_list()
  end

  def route_params(socket) do
    socket
    |> alva_state()
    |> Map.get(:route_params, %{})
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
      collections:
        socket
        |> active_collection_projections()
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

  def on_mount(config, params, _session, socket) do
    %{
      domains: domains,
      collections: collections,
      streams: streams,
      signals: signals,
      subscriptions: subscriptions,
      route_subscriptions: route_subscriptions
    } = normalize_mount_config(config)

    route_params = normalize_route_params(params)
    route_change_collections = route_change_collection_specs(collections)

    socket =
      update_alva(socket, fn state ->
        %{
          state
          | domains: domains,
            route_params: route_params,
            route_change_collections: route_change_collections
        }
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
      if map_size(route_change_collections) == 0 do
        socket
      else
        Phoenix.LiveView.attach_hook(socket, :alva_handle_params, :handle_params, fn
          params, _uri, sock ->
            sock =
              sock
              |> put_route_params(params)
              |> refresh_route_change_collections()

            {:cont, sock}
        end)
      end

    socket =
      Enum.reduce(collections, socket, fn collection_spec, acc_socket ->
        {collection_name, opts} = normalize_collection_spec!(collection_spec)
        collection(acc_socket, collection_name, opts)
      end)

    socket =
      Enum.reduce(streams, socket, fn stream_name, acc_socket ->
        activate_stream(acc_socket, stream_name)
      end)

    socket =
      Enum.reduce(signals, socket, fn signal_name, acc_socket ->
        activate_signal(acc_socket, signal_name)
      end)

    socket = subscribe_route_topics(socket, subscriptions)
    socket = subscribe_projection_route_topics(socket, route_subscriptions)

    {:cont, socket}
  end

  defp handle_notification(notification, sock, events) do
    projections = active_projections(sock, notification, events)

    case projections do
      %{streams: [], collections: [], signals: []} ->
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

  defp active_collection_projections(socket) do
    state = alva_state(socket)

    state.domains
    |> Enum.flat_map(&Alva.Domain.Info.alva_collection_map/1)
    |> Enum.filter(fn {name, _projection} -> MapSet.member?(state.collections, name) end)
  end

  defp active_route_projections(socket) do
    collection_projections =
      socket
      |> active_collection_projections()
      |> Enum.map(fn {name, _projection} -> name end)

    signal_projections =
      socket
      |> active_signal_projections()
      |> Enum.map(fn {name, _projection} -> name end)

    collection_projections ++ signal_projections
  end

  defp refresh_route_change_collections(socket) do
    socket
    |> alva_state()
    |> Map.fetch!(:route_change_collections)
    |> Enum.reduce(socket, fn {name, opts}, acc_socket ->
      next_source_input =
        collection_source_input!(acc_socket, name, collection_source_input_option(opts))

      if next_source_input == active_collection_source_input!(acc_socket, name) do
        acc_socket
      else
        reload_collection(acc_socket, name, source_input: next_source_input)
      end
    end)
  end

  defp active_signal_projections(socket) do
    state = alva_state(socket)

    state.domains
    |> Enum.flat_map(&Alva.Domain.Info.alva_signal_map/1)
    |> Enum.filter(fn {name, _projection} -> MapSet.member?(state.signals, name) end)
  end

  defp ensure_collection_active!(socket, name) do
    if projection_active?(socket, :collection, name) do
      :ok
    else
      raise ArgumentError,
            "Alva collection #{inspect(name)} is not active on this LiveView and cannot be reloaded"
    end
  end

  defp active_collection_source_input!(socket, name) do
    socket
    |> alva_state()
    |> Map.fetch!(:collection_source_inputs)
    |> case do
      %{^name => source_input} -> source_input
      _ -> raise ArgumentError, "Alva collection #{inspect(name)} has no stored source input"
    end
  end

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
        apply_stream_operations(socket, resource, action_events(resource, action_name), data)

      _ ->
        socket
    end
  end

  defp apply_event_stream_operations(socket, _event_name, _result), do: socket

  defp collection_source_items!(_name, _collection, nil), do: []

  defp collection_source_items!(_name, _collection, items) when is_list(items), do: items

  defp collection_source_items!(name, collection, %{results: items}) when is_list(items) do
    collection_source_items!(name, collection, items)
  end

  defp collection_source_items!(name, collection, %{"results" => items}) when is_list(items) do
    collection_source_items!(name, collection, items)
  end

  defp collection_source_items!(name, collection, %{} = envelope) do
    raise ArgumentError,
          "Alva collection #{inspect(name)} source event #{inspect(collection.source.event)} returned a custom envelope whose records could not be inferred. Return a list, use a supported Ash page result, or expose the record field in the source event projection. Got: #{inspect(envelope)}"
  end

  defp collection_source_items!(name, collection, result) do
    raise ArgumentError,
          "Alva collection #{inspect(name)} source event #{inspect(collection.source.event)} must return a list of records or a supported Ash page result, got: #{inspect(result)}"
  end

  defp collection_source_input_option(opts) do
    cond do
      Keyword.has_key?(opts, :source_input) -> Keyword.get(opts, :source_input)
      Keyword.has_key?(opts, :params) -> Keyword.get(opts, :params)
      true -> %{}
    end
  end

  defp collection_source_input!(_socket, _name, source_input) when is_map(source_input),
    do: source_input

  defp collection_source_input!(socket, name, callback) when is_atom(callback) do
    callback
    |> resolve_live_view_callback!(socket, name, "source input")
    |> unwrap_callback_result!(name, "source input", callback)
    |> case do
      source_input when is_map(source_input) ->
        source_input

      source_input ->
        raise ArgumentError,
              "Alva collection #{inspect(name)} source input callback #{inspect(callback)} must return a map, got: #{inspect(source_input)}"
    end
  end

  defp collection_source_input!(_socket, name, source_input) do
    raise ArgumentError,
          "Alva collection #{inspect(name)} source input must be a map or local callback name, got: #{inspect(source_input)}"
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

  defp subscribe_route_topics(socket, subscriptions) do
    topics =
      subscriptions
      |> List.wrap()
      |> Enum.flat_map(&route_subscription_topics!(socket, &1))

    if Phoenix.LiveView.connected?(socket) do
      Enum.reduce(topics, socket, fn topic, acc_socket ->
        subscribe(acc_socket, topic)
      end)
    else
      socket
    end
  end

  defp subscribe_projection_route_topics(socket, route_subscriptions) do
    topics =
      socket
      |> projection_route_topics!(route_subscriptions)
      |> Enum.uniq()

    if Phoenix.LiveView.connected?(socket) do
      Enum.reduce(topics, socket, fn topic, acc_socket ->
        subscribe(acc_socket, topic)
      end)
    else
      socket
    end
  end

  defp projection_route_topics!(socket, route_subscriptions) do
    overrides = normalize_projection_route_subscriptions!(route_subscriptions, socket)

    socket
    |> active_route_projections()
    |> Enum.flat_map(fn projection ->
      case Map.fetch(overrides, projection) do
        {:ok, topics} ->
          normalize_projection_route_subscription_topics!(socket, projection, topics)

        :error ->
          inferred_projection_route_topics!(socket, projection)
      end
    end)
  end

  defp normalize_projection_route_subscriptions!(route_subscriptions, socket) do
    route_subscriptions
    |> List.wrap()
    |> Enum.reduce({MapSet.new(), %{}}, fn spec, {seen, acc} ->
      {projection, topics} = normalize_projection_route_subscription!(socket, spec)

      if MapSet.member?(seen, projection) do
        raise ArgumentError,
              "Alva route_subscriptions contains duplicate entries for #{inspect(projection)}"
      end

      {MapSet.put(seen, projection), Map.put(acc, projection, topics)}
    end)
    |> elem(1)
  end

  defp normalize_projection_route_subscription!(socket, {projection, topics}) do
    ensure_projection_route_subscription_target!(socket, projection)
    {projection, topics}
  end

  defp normalize_projection_route_subscription!(_socket, spec) do
    raise ArgumentError,
          "Alva route_subscriptions entries must be {projection, topics} tuples, got: #{inspect(spec)}"
  end

  defp ensure_projection_route_subscription_target!(socket, projection) when is_atom(projection) do
    if projection_active?(socket, :collection, projection) do
      :ok
    else
      raise ArgumentError,
            "Alva route_subscriptions entry #{inspect(projection)} must reference an active Collection projection"
    end
  end

  defp ensure_projection_route_subscription_target!(socket, projection)
       when is_binary(projection) do
    if projection_active?(socket, :signal, projection) do
      :ok
    else
      raise ArgumentError,
            "Alva route_subscriptions entry #{inspect(projection)} must reference an active Signal projection"
    end
  end

  defp ensure_projection_route_subscription_target!(_socket, projection) do
    raise ArgumentError,
          "Alva route_subscriptions keys must be Collection atoms or Signal names, got: #{inspect(projection)}"
  end

  defp normalize_projection_route_subscription_topics!(_socket, _projection, topic)
       when is_binary(topic),
       do: [topic]

  defp normalize_projection_route_subscription_topics!(socket, _projection, callback)
       when is_atom(callback) do
    route_subscription_topics!(socket, callback)
    |> Enum.uniq()
  end

  defp normalize_projection_route_subscription_topics!(_socket, projection, topics)
       when is_list(topics) do
    if Enum.all?(topics, &is_binary/1) do
      Enum.uniq(topics)
    else
      raise ArgumentError,
            "Alva route_subscriptions entry #{inspect(projection)} must provide a binary topic or list of binary topics, got: #{inspect(topics)}"
    end
  end

  defp normalize_projection_route_subscription_topics!(_socket, projection, topics) do
    raise ArgumentError,
          "Alva route_subscriptions entry #{inspect(projection)} must provide a binary topic or list of binary topics, got: #{inspect(topics)}"
  end

  defp inferred_projection_route_topics!(socket, projection) when is_atom(projection) do
    {resource, collection} = find_projection!(socket, :collection, projection)

    collection
    |> Map.get(:operations, [])
    |> Enum.map(& &1.on)
    |> Enum.uniq()
    |> Enum.flat_map(&publication_topics_for_trigger!(resource, &1, {:collection, projection}))
    |> Enum.uniq()
  end

  defp inferred_projection_route_topics!(socket, projection) when is_binary(projection) do
    {resource, signal} = find_projection!(socket, :signal, projection)

    resource
    |> publication_topics_for_trigger!(signal.on, {:signal, projection})
    |> Enum.uniq()
  end

  defp publication_topics_for_trigger!(resource, trigger, projection_ref) do
    publications =
      resource
      |> Ash.Notifier.PubSub.Info.publications()
      |> Enum.filter(&(publication_identity(&1) == trigger))

    case publications do
      [] ->
        raise ArgumentError,
              "Alva could not infer route_subscriptions for #{route_projection_label(projection_ref)} because no Ash PubSub publication matches trigger #{inspect(trigger)}"

      publications ->
        publications
        |> Enum.flat_map(fn publication ->
          case deterministic_publication_topics(resource, publication) do
            {:ok, topics} ->
              topics

            :dynamic ->
              raise ArgumentError,
                    "Alva could not infer deterministic route_subscriptions for #{route_projection_label(projection_ref)} from trigger #{inspect(trigger)}. Declare route_subscriptions explicitly for this projection."
          end
        end)
        |> Enum.uniq()
    end
  end

  defp deterministic_publication_topics(resource, publication) do
    topic_template = publication.topic

    if deterministic_topic_template?(topic_template) do
      prefix = Ash.Notifier.PubSub.Info.prefix(resource) || ""
      delimiter = Ash.Notifier.PubSub.Info.delimiter(resource)

      topics =
        topic_template
        |> expand_static_topic_template(delimiter)
        |> Enum.map(&finalize_publication_topic(prefix, &1, delimiter))
        |> Enum.uniq()

      {:ok, topics}
    else
      :dynamic
    end
  end

  defp deterministic_topic_template?(topic) when is_binary(topic) or is_nil(topic), do: true
  defp deterministic_topic_template?(topic) when is_atom(topic), do: false
  defp deterministic_topic_template?(topic) when is_list(topic), do: Enum.all?(topic, &deterministic_topic_template?/1)
  defp deterministic_topic_template?(_topic), do: false

  defp expand_static_topic_template(nil, _delimiter), do: [""]
  defp expand_static_topic_template(topic, _delimiter) when is_binary(topic), do: [topic]

  defp expand_static_topic_template(topic, delimiter) when is_list(topic) do
    topic
    |> expand_static_topic_segments([])
    |> Enum.map(&Enum.join(&1, delimiter))
  end

  defp expand_static_topic_segments([], trail), do: [Enum.reverse(trail)]
  defp expand_static_topic_segments([nil | rest], trail), do: expand_static_topic_segments(rest, trail)

  defp expand_static_topic_segments([item | rest], trail) when is_binary(item) do
    expand_static_topic_segments(rest, [item | trail])
  end

  defp expand_static_topic_segments([item | rest], trail) when is_list(item) do
    Enum.flat_map(item, fn possible_value ->
      expand_static_topic_segments([possible_value | rest], trail)
    end)
  end

  defp finalize_publication_topic("", "", _delimiter), do: ""
  defp finalize_publication_topic(prefix, "", _delimiter), do: prefix
  defp finalize_publication_topic("", topic, _delimiter), do: topic
  defp finalize_publication_topic(prefix, topic, delimiter), do: "#{prefix}#{delimiter}#{topic}"

  defp route_projection_label({:collection, projection}),
    do: "Collection #{inspect(projection)}"

  defp route_projection_label({:signal, projection}), do: "Signal #{inspect(projection)}"

  defp route_subscription_topics!(_socket, topic) when is_binary(topic), do: [topic]

  defp route_subscription_topics!(_socket, topics) when is_list(topics) do
    if Enum.all?(topics, &is_binary/1) do
      topics
    else
      raise ArgumentError,
            "Alva route subscriptions must be binary topics, lists of binary topics, or local callback names, got: #{inspect(topics)}"
    end
  end

  defp route_subscription_topics!(socket, callback) when is_atom(callback) do
    callback
    |> resolve_route_callback!(socket, :subscription)
    |> unwrap_route_callback_result!(:subscription, callback)
    |> normalize_route_subscription_topics!(callback)
  end

  defp route_subscription_topics!(_socket, topic) do
    raise ArgumentError,
          "Alva route subscriptions must be binary topics, lists of binary topics, or local callback names, got: #{inspect(topic)}"
  end

  defp normalize_route_subscription_topics!(topic, _callback) when is_binary(topic), do: [topic]

  defp normalize_route_subscription_topics!(topics, callback) when is_list(topics) do
    if Enum.all?(topics, &is_binary/1) do
      topics
    else
      raise_invalid_route_subscription_callback!(callback, topics)
    end
  end

  defp normalize_route_subscription_topics!(topics, callback) do
    raise_invalid_route_subscription_callback!(callback, topics)
  end

  defp raise_invalid_route_subscription_callback!(callback, topics) do
    raise ArgumentError,
          "Alva route subscription callback #{inspect(callback)} must return a binary topic or list of binary topics, got: #{inspect(topics)}"
  end

  defp resolve_route_callback!(callback, %{view: view} = socket, kind)
       when is_atom(view) and not is_nil(view) do
    cond do
      function_exported?(view, callback, 1) ->
        apply(view, callback, [socket])

      function_exported?(view, callback, 0) ->
        apply(view, callback, [])

      true ->
        raise ArgumentError,
              "Alva route #{kind} callback #{inspect(callback)} is not defined on #{inspect(view)}"
    end
  end

  defp resolve_route_callback!(callback, _socket, kind) do
    raise ArgumentError,
          "Alva route #{kind} callback #{inspect(callback)} requires socket.view to be set"
  end

  defp unwrap_route_callback_result!({:ok, value}, _kind, _callback), do: value

  defp unwrap_route_callback_result!({:error, reason}, kind, callback) do
    raise ArgumentError,
          "Alva route #{kind} callback #{inspect(callback)} failed: #{inspect(reason)}"
  end

  defp unwrap_route_callback_result!(value, _kind, _callback), do: value

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
    socket =
      socket
      |> active_collection_projections()
      |> Enum.flat_map(fn {name, {resource, collection}} ->
        if resource == notification_resource do
          collection.operations
          |> Enum.filter(&MapSet.member?(events, &1.on))
          |> Enum.map(&{name, &1})
        else
          []
        end
      end)
      |> Enum.reduce(socket, fn {name, operation}, acc_socket ->
        apply_collection_operation(acc_socket, name, operation, data)
      end)

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

  defp apply_collection_operation(socket, name, %{op: :delete}, data) do
    Phoenix.LiveView.stream_delete(socket, name, Alva.Dispatcher.strip_metadata(data))
  end

  defp apply_collection_operation(socket, name, %{op: :update} = operation, data) do
    Phoenix.LiveView.stream_insert(
      socket,
      name,
      Alva.Dispatcher.strip_metadata(data),
      collection_operation_opts(operation, update_only: true)
    )
  end

  defp apply_collection_operation(socket, name, %{op: :insert} = operation, data) do
    item = Alva.Dispatcher.strip_metadata(data)

    if pending_collection_insert?(socket, name, item) do
      socket
    else
      Phoenix.LiveView.stream_insert(socket, name, item, collection_operation_opts(operation))
    end
  end

  defp pending_collection_insert?(socket, name, %{id: id}) do
    dom_id = "#{name}-#{id}"

    socket.assigns
    |> Map.get(:streams, %{})
    |> Map.get(name, %{})
    |> Map.get(:inserts, [])
    |> Enum.any?(fn
      {^dom_id, _at, _item, _limit, _update_only} -> true
      _other -> false
    end)
  end

  defp pending_collection_insert?(_socket, _name, _item), do: false

  defp collection_operation_opts(operation, defaults \\ []) do
    defaults
    |> Keyword.merge(
      operation
      |> Map.take([:at, :limit, :update_only])
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    )
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

  defp normalize_mount_config(%{domains: domains} = config) when is_list(domains) do
    %{
      domains: domains,
      collections: Map.get(config, :collections, []),
      streams: Map.get(config, :streams, []),
      signals: Map.get(config, :signals, []),
      subscriptions: Map.get(config, :subscriptions, []),
      route_subscriptions: Map.get(config, :route_subscriptions, [])
    }
  end

  defp normalize_mount_config({domains, collections})
       when is_list(domains) and is_list(collections) do
    %{
      domains: domains,
      collections: collections,
      streams: [],
      signals: [],
      subscriptions: [],
      route_subscriptions: []
    }
  end

  defp normalize_mount_config({domains, collections, streams, subscriptions})
       when is_list(domains) and is_list(collections) and is_list(streams) and
              is_list(subscriptions) do
    %{
      domains: domains,
      collections: collections,
      streams: streams,
      signals: [],
      subscriptions: subscriptions,
      route_subscriptions: []
    }
  end

  defp normalize_mount_config({
         domains,
         collections,
         streams,
         signals,
         subscriptions,
         route_subscriptions
       })
       when is_list(domains) and is_list(collections) and is_list(streams) and
              is_list(signals) and is_list(subscriptions) and is_list(route_subscriptions) do
    %{
      domains: domains,
      collections: collections,
      streams: streams,
      signals: signals,
      subscriptions: subscriptions,
      route_subscriptions: route_subscriptions
    }
  end

  defp normalize_mount_config(domains) when is_list(domains) do
    %{
      domains: domains,
      collections: [],
      streams: [],
      signals: [],
      subscriptions: [],
      route_subscriptions: []
    }
  end

  defp normalize_route_params(params) when is_map(params), do: params
  defp normalize_route_params(_params), do: %{}

  defp route_change_collection_specs(collections) do
    collections
    |> Enum.map(&normalize_collection_spec!/1)
    |> Enum.filter(fn {_name, opts} -> Keyword.get(opts, :reload_on) == :route_change end)
    |> Map.new()
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
    publication_events(resource, action)
  end

  defp notification_events(%Ash.Notifier.Notification{action: %{name: name}}) do
    MapSet.new([to_string(name)])
  end

  defp notification_events(_notification), do: MapSet.new()

  defp broadcast_events(%Phoenix.Socket.Broadcast{event: event}) do
    MapSet.new([to_string(event)])
  end

  defp action_events(resource, action_name) when is_atom(resource) do
    case Ash.Resource.Info.action(resource, action_name) do
      nil ->
        MapSet.new([to_string(action_name)])

      action ->
        publication_events(resource, action)
    end
  end

  defp publication_events(resource, action) do
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

  defp put_route_params(socket, params) do
    route_params = normalize_route_params(params)

    update_alva(socket, fn state ->
      %{state | route_params: route_params}
    end)
  end

  defp assign_stream_if_missing(socket, name) do
    if Map.has_key?(socket.assigns, name) do
      socket
    else
      Phoenix.Component.assign(socket, name, nil)
    end
  end

  defp alva_state(socket) do
    Map.get(socket.private, @alva_private_key, %{
      domains: [],
      route_subscriptions: MapSet.new(),
      route_params: %{},
      route_change_collections: %{},
      streams: MapSet.new(),
      collections: MapSet.new(),
      collection_source_inputs: %{},
      signals: MapSet.new()
    })
  end
end
