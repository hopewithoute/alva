defmodule Alva.LiveView do
  @moduledoc """
  A macro to inject Alva-specific functionality into Phoenix LiveViews.
  """

  @alva_private_key :alva
  @public_activation_keys [:domains, :collections, :signals, :route_subscriptions]
  @public_collection_option_keys [:source_input, :reload_on]

  defmacro __using__(opts) do
    validate_use_opts!(opts, __CALLER__)

    quote do
      import Alva.LiveView
      @alva_domains Keyword.get(unquote(opts), :domains, [])
      @alva_collections Keyword.get(unquote(opts), :collections, [])
      @alva_signals Keyword.get(unquote(opts), :signals, [])
      @alva_route_subscriptions Keyword.get(unquote(opts), :route_subscriptions, [])
      on_mount(
        {Alva.LiveView,
         %{
           domains: @alva_domains,
           collections: @alva_collections,
           signals: @alva_signals,
           route_subscriptions: @alva_route_subscriptions
         }}
      )
    end
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
    {_event_resource, source_event} = find_event_declaration!(socket, collection.source.event)
    source_input = collection_source_input!(socket, name, collection_source_input_option(opts))

    result =
      Alva.Dispatcher.dispatch(source_event.name, source_input,
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

  def activate_signal(socket, key) when is_atom(key) do
    ensure_projection!(socket, :signal, key)

    update_alva(socket, fn state ->
      update_in(state.signals, &MapSet.put(&1, key))
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
    active_projections(socket, notification, notification_occurrence_keys(notification))
  end

  def active_projections(
        socket,
        %Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{} = notification}
      ) do
    active_projections(socket, notification, notification_occurrence_keys(notification))
  end

  defp active_projections(
         socket,
         %Ash.Notifier.Notification{resource: notification_resource},
         occurrence_keys
       ) do
    %{
      streams:
        socket
        |> active_stream_projections()
        |> Enum.filter(&stream_projection_matches?(&1, notification_resource, occurrence_keys))
        |> Enum.map(fn {name, _projection} -> name end),
      collections:
        socket
        |> active_collection_projections()
        |> Enum.filter(
          &collection_projection_matches?(&1, notification_resource, occurrence_keys)
        )
        |> Enum.map(fn {name, _projection} -> name end),
      signals:
        socket
        |> active_signal_projections()
        |> Enum.filter(fn {_name, {resource, signal}} ->
          resource == notification_resource and MapSet.member?(occurrence_keys, signal.on)
        end)
        |> Enum.map(fn {name, _projection} -> name end)
    }
  end

  def on_mount(config, params, _session, socket) do
    %{
      domains: domains,
      collections: collections,
      signals: signals,
      route_subscriptions: route_subscriptions
    } = normalize_mount_config(config)

    route_params = normalize_route_params(params)
    collection_specs = collection_activation_specs(collections)
    route_change_collections = route_change_collection_specs(collections)
    route_subscription_callbacks = callback_route_subscriptions?(route_subscriptions)

    socket =
      update_alva(socket, fn state ->
        %{
          state
          | domains: domains,
            collection_specs: collection_specs,
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
          handle_notification(notification, sock, notification_occurrence_keys(notification))

        %Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{} = notification} =
            broadcast,
        sock ->
          _ = broadcast
          handle_notification(notification, sock, notification_occurrence_keys(notification))

        _msg, sock ->
          {:cont, sock}
      end)

    socket =
      cond do
        map_size(route_change_collections) == 0 and not route_subscription_callbacks ->
          socket

        map_size(route_change_collections) == 0 and route_subscription_callbacks and
            not route_lifecycle_available?(socket) ->
          socket

        true ->
          Phoenix.LiveView.attach_hook(socket, :alva_handle_params, :handle_params, fn
            params, _uri, sock ->
              sock =
                sock
                |> put_route_params(params)
                |> sync_projection_route_topics(route_subscriptions)
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
      Enum.reduce(signals, socket, fn signal_name, acc_socket ->
        activate_signal(acc_socket, signal_name)
      end)

    socket = sync_projection_route_topics(socket, route_subscriptions)

    {:cont, socket}
  end

  defp handle_notification(notification, sock, occurrence_keys) do
    projections = active_projections(sock, notification, occurrence_keys)

    case projections do
      %{streams: [], collections: [], signals: []} ->
        {:cont, sock}

      %{signals: signals} ->
        sock = apply_stream_operations(sock, notification, occurrence_keys)

        if signals == [] do
          {:halt, sock}
        else
          {:halt, push_signals(sock, notification, occurrence_keys)}
        end
    end
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
        apply_stream_operations(
          socket,
          resource,
          action_occurrence_keys(resource, action_name),
          data
        )

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
        subscribe_transport_topic(acc_socket, topic)
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

  defp sync_projection_route_topics(socket, route_subscriptions) do
    previous_topics =
      socket
      |> route_subscriptions()
      |> MapSet.new()

    next_topics =
      socket
      |> projection_route_topics!(route_subscriptions)
      |> MapSet.new()

    socket =
      update_alva(socket, fn state ->
        %{state | route_subscriptions: next_topics}
      end)

    if Phoenix.LiveView.connected?(socket) do
      socket
      |> unsubscribe_projection_route_topics(previous_topics, next_topics)
      |> subscribe_projection_route_topics(previous_topics, next_topics)
    else
      socket
    end
  end

  defp unsubscribe_projection_route_topics(socket, previous_topics, next_topics) do
    previous_topics
    |> MapSet.difference(next_topics)
    |> Enum.reduce(socket, fn topic, acc_socket ->
      unsubscribe_transport_topic(acc_socket, topic)
    end)
  end

  defp subscribe_projection_route_topics(socket, previous_topics, next_topics) do
    next_topics
    |> MapSet.difference(previous_topics)
    |> Enum.reduce(socket, fn topic, acc_socket ->
      subscribe_transport_topic(acc_socket, topic)
    end)
  end

  defp subscribe_transport_topic(socket, topic) when is_binary(topic) do
    pubsub = endpoint_pubsub!(socket)
    :ok = Phoenix.PubSub.subscribe(pubsub, topic)
    socket
  end

  defp unsubscribe_transport_topic(socket, topic) when is_binary(topic) do
    pubsub = endpoint_pubsub!(socket)
    :ok = Phoenix.PubSub.unsubscribe(pubsub, topic)
    socket
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

  defp ensure_projection_route_subscription_target!(socket, projection)
       when is_atom(projection) do
    cond do
      projection_active?(socket, :collection, projection) ->
        :ok

      projection_active?(socket, :signal, projection) ->
        :ok

      true ->
        raise ArgumentError,
              "Alva route_subscriptions entry #{inspect(projection)} must reference an active Collection or Signal projection"
    end
  end

  defp ensure_projection_route_subscription_target!(_socket, projection) do
    raise ArgumentError,
          "Alva route_subscriptions keys must be Collection or Signal declaration key atoms, got: #{inspect(projection)}"
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
    cond do
      projection_active?(socket, :collection, projection) ->
        ensure_collection_route_inference_static!(socket, projection)
        {resource, collection} = find_projection!(socket, :collection, projection)

        collection
        |> Map.get(:operations, [])
        |> Enum.map(& &1.on)
        |> Enum.uniq()
        |> Enum.flat_map(
          &publication_topics_for_trigger!(resource, &1, {:collection, projection})
        )
        |> Enum.uniq()

      projection_active?(socket, :signal, projection) ->
        {resource, signal} = find_projection!(socket, :signal, projection)

        resource
        |> publication_topics_for_trigger!(signal.on, {:signal, projection, signal.name})
        |> Enum.uniq()

      true ->
        raise ArgumentError,
              "Alva could not infer route_subscriptions for unknown projection #{inspect(projection)}"
    end
  end

  defp publication_topics_for_trigger!(resource, trigger, projection_ref) do
    publications =
      resource
      |> Ash.Notifier.PubSub.Info.publications()
      |> Enum.filter(&(publication_occurrence_key(&1) == trigger))

    case publications do
      [] ->
        raise ArgumentError,
              "Alva could not infer route_subscriptions for #{route_projection_label(projection_ref)} because no Ash PubSub publication matches trigger #{inspect(trigger)}"

      [publication] ->
        case deterministic_publication_topics(resource, publication) do
          {:ok, topics} ->
            Enum.uniq(topics)

          :dynamic ->
            raise ArgumentError,
                  "Alva could not infer deterministic route_subscriptions for #{route_projection_label(projection_ref)} from trigger #{inspect(trigger)}. Declare route_subscriptions explicitly for this projection."
        end

      _publications ->
        raise ArgumentError,
              "Alva could not infer deterministic route_subscriptions for #{route_projection_label(projection_ref)} from trigger #{inspect(trigger)} because multiple Ash PubSub publications match. Declare route_subscriptions explicitly for this projection."
    end
  end

  defp ensure_collection_route_inference_static!(socket, projection) do
    opts =
      socket
      |> alva_state()
      |> Map.get(:collection_specs, %{})
      |> Map.get(projection, [])

    source_input = Keyword.get(opts, :source_input)

    cond do
      Keyword.get(opts, :reload_on) == :route_change ->
        raise ArgumentError,
              "Alva could not infer deterministic route_subscriptions for Collection #{inspect(projection)} because its Topic wiring depends on Page Scope (`reload_on: :route_change`). Declare route_subscriptions explicitly for this projection."

      is_atom(source_input) and route_params(socket) != %{} ->
        raise ArgumentError,
              "Alva could not infer deterministic route_subscriptions for Collection #{inspect(projection)} because its source_input callback #{inspect(source_input)} may depend on Page Scope route params. Declare route_subscriptions explicitly for this projection."

      true ->
        :ok
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

  defp deterministic_topic_template?(topic) when is_list(topic),
    do: Enum.all?(topic, &deterministic_topic_template?/1)

  defp deterministic_topic_template?(_topic), do: false

  defp expand_static_topic_template(nil, _delimiter), do: [""]
  defp expand_static_topic_template(topic, _delimiter) when is_binary(topic), do: [topic]

  defp expand_static_topic_template(topic, delimiter) when is_list(topic) do
    topic
    |> expand_static_topic_segments([])
    |> Enum.map(&Enum.join(&1, delimiter))
  end

  defp expand_static_topic_segments([], trail), do: [Enum.reverse(trail)]

  defp expand_static_topic_segments([nil | rest], trail),
    do: expand_static_topic_segments(rest, trail)

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

  defp route_projection_label({:signal, _projection, name}), do: "Signal #{inspect(name)}"
  defp route_projection_label({:signal, projection}), do: "Signal #{inspect(projection)}"

  defp route_subscription_topics!(socket, callback) when is_atom(callback) do
    callback
    |> resolve_route_callback!(socket, :subscription)
    |> unwrap_route_callback_result!(:subscription, callback)
    |> normalize_route_subscription_topics!(callback)
  end

  defp route_subscription_topics!(_socket, topic) do
    raise ArgumentError,
          "Alva route subscriptions expect a local callback name when callback normalization is required, got: #{inspect(topic)}"
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
    |> Enum.reduce(socket, fn {_key, {_resource, signal}}, acc_socket ->
      Phoenix.LiveView.push_event(acc_socket, signal.name, signal_payload(data, signal))
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
       when is_atom(event) or is_binary(event) do
    apply_stream_operations(socket, notification_resource, MapSet.new([event]), data)
  end

  defp apply_stream_operations(socket, notification_resource, occurrence_keys, data) do
    socket =
      socket
      |> active_collection_projections()
      |> Enum.flat_map(fn {name, {resource, collection}} ->
        if resource == notification_resource do
          collection.operations
          |> Enum.filter(&MapSet.member?(occurrence_keys, &1.on))
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
        |> Enum.filter(&MapSet.member?(occurrence_keys, &1.on))
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
         occurrence_keys
       ) do
    resource == notification_resource and
      Enum.any?(stream.operations, &MapSet.member?(occurrence_keys, &1.on))
  end

  defp collection_projection_matches?(
         {_name, {resource, collection}},
         notification_resource,
         occurrence_keys
       ) do
    resource == notification_resource and
      Enum.any?(collection.operations, &MapSet.member?(occurrence_keys, &1.on))
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

  defp find_event_declaration!(socket, key) do
    domains = alva_state(socket).domains

    event_projection =
      Enum.find_value(domains, fn domain ->
        domain
        |> Alva.Domain.Info.alva_event_key_map()
        |> Map.get(key)
      end)

    case event_projection do
      nil ->
        raise ArgumentError,
              "Unknown Alva event declaration #{inspect(key)} for mounted domains #{inspect(domains)}"

      event_projection ->
        event_projection
    end
  end

  defp normalize_mount_config(%{domains: domains} = config) when is_list(domains) do
    validate_mount_config_keys!(config)
    collections = Map.get(config, :collections, [])
    signals = Map.get(config, :signals, [])

    validate_collection_activation_specs!(collections)
    validate_signal_activation_specs!(signals)
    validate_projection_namespace_activation_specs!(collections, signals)

    %{
      domains: domains,
      collections: collections,
      signals: signals,
      route_subscriptions: Map.get(config, :route_subscriptions, [])
    }
  end

  defp normalize_mount_config(config) when is_tuple(config) do
    raise ArgumentError,
          "Alva declarative page activation no longer supports legacy tuple mount config. Use keyword-form `use Alva.LiveView` or pass a map with :domains, :collections, :signals, and :route_subscriptions."
  end

  defp normalize_mount_config(domains) when is_list(domains) do
    if Keyword.keyword?(domains) do
      raise ArgumentError,
            "Alva declarative page activation maps must be passed as a map, not a keyword list. Use keyword-form `use Alva.LiveView` or pass %{domains: ..., collections: ..., signals: ..., route_subscriptions: ...}."
    else
      %{
        domains: domains,
        collections: [],
        signals: [],
        route_subscriptions: []
      }
    end
  end

  defp normalize_mount_config(config) do
    raise ArgumentError,
          "Alva declarative page activation must be configured with keyword-form `use Alva.LiveView` or a map containing :domains, :collections, :signals, and :route_subscriptions. Got: #{inspect(config)}"
  end

  defp normalize_route_params(params) when is_map(params), do: params
  defp normalize_route_params(_params), do: %{}

  defp route_lifecycle_available?(%{router: router}) when not is_nil(router), do: true
  defp route_lifecycle_available?(_socket), do: false

  defp callback_route_subscriptions?(route_subscriptions) when is_list(route_subscriptions) do
    Enum.any?(route_subscriptions, fn
      {_projection, topic_spec} -> is_atom(topic_spec)
      _other -> false
    end)
  end

  defp callback_route_subscriptions?(_route_subscriptions), do: false

  defp route_change_collection_specs(collections) do
    collections
    |> Enum.map(&normalize_collection_spec!/1)
    |> Enum.filter(fn {_name, opts} -> Keyword.get(opts, :reload_on) == :route_change end)
    |> Map.new()
  end

  defp normalize_collection_spec!(name) when is_atom(name), do: {name, []}

  defp normalize_collection_spec!({name, opts}) when is_atom(name) and is_list(opts) do
    validate_collection_activation_opts!(name, opts)
    {name, opts}
  end

  defp normalize_collection_spec!(spec) do
    raise ArgumentError,
          "Alva collection activation must be an atom name or {name, opts}, got: #{inspect(spec)}"
  end

  defp collection_activation_specs(collections) do
    collections
    |> Enum.map(&normalize_collection_spec!/1)
    |> Map.new()
  end

  defp validate_use_opts!(opts, caller) when is_list(opts) do
    if Keyword.keyword?(opts) do
      opts
      |> Keyword.keys()
      |> Enum.each(&validate_public_activation_key!(&1, caller))

      collections =
        case Keyword.fetch(opts, :collections) do
          {:ok, collections} -> validate_collection_use_declarations!(collections, caller)
          :error -> []
        end

      signals =
        case Keyword.fetch(opts, :signals) do
          {:ok, signals} -> validate_signal_use_declarations!(signals, caller)
          :error -> []
        end

      validate_projection_namespace_use_declarations!(collections, signals, caller)

      case Keyword.fetch(opts, :route_subscriptions) do
        {:ok, route_subscriptions} ->
          validate_route_subscription_use_declarations!(
            route_subscriptions,
            collections,
            signals,
            caller
          )

        :error ->
          :ok
      end
    else
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description:
          "use Alva.LiveView expects keyword options. Use keyword-form declarative activation with :domains, :collections, :signals, and :route_subscriptions."
    end
  end

  defp validate_use_opts!(_opts, caller) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description:
        "use Alva.LiveView expects keyword options. Use keyword-form declarative activation with :domains, :collections, :signals, and :route_subscriptions."
  end

  defp validate_public_activation_key!(:streams, caller) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description:
        "Alva declarative page activation no longer accepts top-level `streams:`. Activate collections declaratively with `collections:` or use imperative `Alva.LiveView.activate_stream/2`."
  end

  defp validate_public_activation_key!(:subscriptions, caller) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description:
        "Alva declarative page activation no longer accepts top-level `subscriptions:`. Move topic wiring to top-level `route_subscriptions:` or use raw Phoenix PubSub outside Alva projections."
  end

  defp validate_public_activation_key!(key, caller) do
    unless key in @public_activation_keys do
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description:
          "Alva declarative page activation only accepts :domains, :collections, :signals, and :route_subscriptions. Unsupported key: #{inspect(key)}"
    end
  end

  defp validate_collection_use_declarations!(collections, caller) when is_list(collections) do
    names =
      Enum.map(collections, fn
        name when is_atom(name) ->
          name

        {name, opts} when is_atom(name) and is_list(opts) ->
          validate_collection_use_opts!(name, opts, caller)
          name

        other ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "Alva declarative `collections:` entries must be atoms or keyword entries like `collections: [sales_orders: [source_input: :callback]]`. Got: #{inspect(other)}"
      end)

    validate_unique_activation_names!(names, :collection, caller)
    names
  end

  defp validate_collection_use_declarations!(_collections, caller) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description: "Alva declarative `collections:` must be a list."
  end

  defp validate_collection_use_opts!(name, opts, caller) when is_list(opts) do
    if Keyword.keyword?(opts) do
      Enum.each(Keyword.keys(opts), fn
        :source_input ->
          :ok

        :reload_on ->
          :ok

        :params ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "Alva declarative collection #{inspect(name)} no longer accepts `params:`. Use `source_input:` instead."

        :subscriptions ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "Alva declarative collection #{inspect(name)} no longer accepts nested `subscriptions:`. Move topic wiring to top-level `route_subscriptions:`."

        key ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "Alva declarative collection #{inspect(name)} only accepts :source_input and :reload_on options. Unsupported option: #{inspect(key)}"
      end)
    else
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description:
          "Alva declarative collection #{inspect(name)} options must be a keyword list containing only :source_input and :reload_on."
    end
  end

  defp validate_collection_use_opts!(name, _opts, caller) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description:
        "Alva declarative collection #{inspect(name)} options must be a keyword list containing only :source_input and :reload_on."
  end

  defp validate_signal_use_declarations!(signals, caller) when is_list(signals) do
    keys =
      Enum.map(signals, fn
        key when is_atom(key) ->
          key

        name when is_binary(name) ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "Alva declarative `signals:` no longer accepts browser-facing string names like #{inspect(name)}. Use the signal declaration key atom instead."

        {key, _opts} when is_atom(key) ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "Alva declarative `signals:` only accepts atom declaration keys. Remove tuple options for #{inspect(key)} and keep client-facing names in the resource declaration."

        other ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "Alva declarative `signals:` entries must be atom declaration keys, got: #{inspect(other)}"
      end)

    validate_unique_activation_names!(keys, :signal, caller)
    keys
  end

  defp validate_signal_use_declarations!(_signals, caller) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description: "Alva declarative `signals:` must be a list of atom declaration keys."
  end

  defp validate_unique_activation_names!(names, kind, caller) do
    names
    |> Enum.frequencies()
    |> Enum.each(fn
      {_name, 1} ->
        :ok

      {name, _count} ->
        raise CompileError,
          file: caller.file,
          line: caller.line,
          description:
            "Alva declarative #{kind} activation contains duplicate entries for #{inspect(name)}."
    end)
  end

  defp validate_projection_namespace_use_declarations!(collections, signals, caller) do
    collections
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(signals))
    |> Enum.each(fn key ->
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description:
          "Alva declarative page activation cannot activate the same projection key in both `collections:` and `signals:`: #{inspect(key)}"
    end)
  end

  defp validate_route_subscription_use_declarations!(
         route_subscriptions,
         collections,
         signals,
         caller
       )
       when is_list(route_subscriptions) do
    active_projections = MapSet.new(collections ++ signals)

    projections =
      Enum.map(route_subscriptions, fn
        {projection, topics} when is_atom(projection) ->
          unless MapSet.member?(active_projections, projection) do
            raise CompileError,
              file: caller.file,
              line: caller.line,
              description:
                "Alva declarative route_subscriptions entry #{inspect(projection)} must reference an activated Collection or Signal projection on the same page."
          end

          validate_route_subscription_use_topics!(projection, topics, caller)
          projection

        {projection, _topics} ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "Alva route_subscriptions keys must be Collection or Signal declaration key atoms, got: #{inspect(projection)}"

        spec ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "Alva route_subscriptions entries must be {projection, topics} tuples, got: #{inspect(spec)}"
      end)

    validate_unique_route_subscription_names!(projections, caller)
  end

  defp validate_route_subscription_use_declarations!(
         _route_subscriptions,
         _collections,
         _signals,
         caller
       ) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description:
        "Alva declarative `route_subscriptions:` must be a list of {projection, topics} tuples."
  end

  defp validate_route_subscription_use_topics!(_projection, topic, _caller)
       when is_binary(topic) or is_atom(topic),
       do: :ok

  defp validate_route_subscription_use_topics!(projection, topics, caller) when is_list(topics) do
    if Enum.all?(topics, &is_binary/1) do
      :ok
    else
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description:
          "Alva route_subscriptions entry #{inspect(projection)} must provide a binary topic or list of binary topics, got: #{inspect(topics)}"
    end
  end

  defp validate_route_subscription_use_topics!(projection, topics, caller) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description:
        "Alva route_subscriptions entry #{inspect(projection)} must provide a binary topic or list of binary topics, got: #{inspect(topics)}"
  end

  defp validate_unique_route_subscription_names!(projections, caller) do
    projections
    |> Enum.frequencies()
    |> Enum.each(fn
      {_projection, 1} ->
        :ok

      {projection, _count} ->
        raise CompileError,
          file: caller.file,
          line: caller.line,
          description:
            "Alva route_subscriptions contains duplicate entries for #{inspect(projection)}"
    end)
  end

  defp validate_mount_config_keys!(config) do
    config
    |> Map.keys()
    |> Enum.each(fn
      :domains ->
        :ok

      :collections ->
        :ok

      :signals ->
        :ok

      :route_subscriptions ->
        :ok

      :streams ->
        raise ArgumentError,
              "Alva declarative page activation no longer accepts top-level `streams:`. Activate collections declaratively with `collections:` or use imperative `Alva.LiveView.activate_stream/2`."

      :subscriptions ->
        raise ArgumentError,
              "Alva declarative page activation no longer accepts top-level `subscriptions:`. Move topic wiring to top-level `route_subscriptions:` or use raw Phoenix PubSub outside Alva projections."

      key ->
        raise ArgumentError,
              "Alva declarative page activation only accepts :domains, :collections, :signals, and :route_subscriptions. Unsupported key: #{inspect(key)}"
    end)
  end

  defp validate_collection_activation_specs!(collections) when is_list(collections) do
    names =
      collections
      |> Enum.map(&normalize_collection_spec!/1)
      |> Enum.map(&elem(&1, 0))

    validate_unique_activation_specs!(names, :collection)
  end

  defp validate_collection_activation_specs!(collections) do
    raise ArgumentError,
          "Alva declarative `collections:` must be a list, got: #{inspect(collections)}"
  end

  defp validate_collection_activation_opts!(name, opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "Alva collection #{inspect(name)} activation options must be a keyword list containing only :source_input and :reload_on."
    end

    Enum.each(Keyword.keys(opts), fn
      key when key in @public_collection_option_keys ->
        :ok

      :params ->
        raise ArgumentError,
              "Alva declarative collection #{inspect(name)} no longer accepts `params:`. Use `source_input:` instead."

      :subscriptions ->
        raise ArgumentError,
              "Alva declarative collection #{inspect(name)} no longer accepts nested `subscriptions:`. Move topic wiring to top-level `route_subscriptions:`."

      key ->
        raise ArgumentError,
              "Alva declarative collection #{inspect(name)} only accepts :source_input and :reload_on options. Unsupported option: #{inspect(key)}"
    end)
  end

  defp validate_signal_activation_specs!(signals) when is_list(signals) do
    keys =
      Enum.map(signals, fn
        key when is_atom(key) ->
          key

        name when is_binary(name) ->
          raise ArgumentError,
                "Alva declarative `signals:` no longer accepts browser-facing string names like #{inspect(name)}. Use the signal declaration key atom instead."

        {key, _opts} when is_atom(key) ->
          raise ArgumentError,
                "Alva declarative `signals:` only accepts atom declaration keys. Remove tuple options for #{inspect(key)} and keep client-facing names in the resource declaration."

        other ->
          raise ArgumentError,
                "Alva declarative `signals:` entries must be atom declaration keys, got: #{inspect(other)}"
      end)

    validate_unique_activation_specs!(keys, :signal)
  end

  defp validate_signal_activation_specs!(signals) do
    raise ArgumentError,
          "Alva declarative `signals:` must be a list of atom declaration keys, got: #{inspect(signals)}"
  end

  defp validate_unique_activation_specs!(names, kind) do
    names
    |> Enum.frequencies()
    |> Enum.each(fn
      {_name, 1} ->
        :ok

      {name, _count} ->
        raise ArgumentError,
              "Alva declarative #{kind} activation contains duplicate entries for #{inspect(name)}."
    end)
  end

  defp validate_projection_namespace_activation_specs!(collections, signals) do
    collections
    |> Enum.map(&normalize_collection_spec!/1)
    |> Enum.map(&elem(&1, 0))
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(signals))
    |> Enum.each(fn key ->
      raise ArgumentError,
            "Alva declarative page activation cannot activate the same projection key in both `collections:` and `signals:`: #{inspect(key)}"
    end)
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

  defp notification_occurrence_keys(%Ash.Notifier.Notification{action: %{name: name}})
       when is_atom(name) do
    MapSet.new([name])
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

  defp publication_occurrence_key(%{action: action}) when not is_nil(action), do: action
  defp publication_occurrence_key(%{type: type}) when not is_nil(type), do: type
  defp publication_occurrence_key(_publication), do: nil

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
      collection_specs: %{},
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
