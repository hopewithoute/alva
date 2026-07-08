defmodule Alva.LiveView do
  @moduledoc """
  A macro to inject Alva-specific functionality into Phoenix LiveViews.
  """

  @alva_private_key :alva
  @public_activation_keys [
    :collections,
    :signals,
    :route_subscriptions,
    :subscriptions,
    :page_events,
    :page_state,
    :commands
  ]
  @public_collection_option_keys [:source_input, :reload_on]
  @public_subscription_option_keys [:activate]
  @upload_change_event "alva.validate_upload"
  @upload_submit_event "alva.save_upload"
  @err_domains_removed "Alva declarative page activation no longer accepts `domains:`. Prefer `subscriptions:` for the supported V2 path; projection lookup now resolves through the consuming host app registry."
  @err_streams_removed "Alva declarative page activation no longer accepts top-level `streams:`. For the supported V2 path, expose typed `subscription` capabilities and activate them with `subscriptions:`."

  @err_opts_expected "use Alva.LiveView expects keyword options. Prefer keyword-form `use Alva.LiveView, subscriptions: [...]` for the supported V2 path; legacy :collections, :signals, :route_subscriptions, :page_events, and :page_state remain compatibility surfaces."
  defp err_unsupported_key(key),
    do:
      "Alva declarative page activation only accepts :subscriptions and :commands on the supported V2 path, plus legacy compatibility keys :collections, :signals, :route_subscriptions, :page_events, and :page_state. Unsupported key: #{inspect(key)}"

  defmacro __using__(opts) do
    validate_use_opts!(opts, __CALLER__)

    quote do
      import Alva.LiveView
      @alva_collections Keyword.get(unquote(opts), :collections, [])
      @alva_signals Keyword.get(unquote(opts), :signals, [])
      @alva_route_subscriptions Keyword.get(unquote(opts), :route_subscriptions, [])
      @alva_page_events Keyword.get(unquote(opts), :page_events, [])
      @alva_page_state Keyword.get(unquote(opts), :page_state)
      @alva_subscriptions Keyword.get(unquote(opts), :subscriptions, [])
      @alva_commands Keyword.get(unquote(opts), :commands, [])

      @doc false
      def __alva_page_events__, do: @alva_page_events

      def handle_params(_params, _uri, socket), do: {:noreply, socket}
      defoverridable handle_params: 3

      on_mount(
        {Alva.LiveView,
         %{
           collections: @alva_collections,
           signals: @alva_signals,
           route_subscriptions: @alva_route_subscriptions,
           page_events: @alva_page_events,
           page_state: @alva_page_state,
           subscriptions: @alva_subscriptions,
           commands: @alva_commands
         }}
      )
    end
  end

  def collection(socket, name, opts \\ [])

  def collection(socket, name, opts) when is_atom(name) and is_list(opts) do
    {resource, collection} = find_projection!(socket, :collection, name)

    {_event_resource, source_event} =
      find_resource_event_declaration!(resource, collection.source.event)

    source_input = collection_source_input!(socket, name, collection_source_input_option(opts))

    result =
      Alva.Dispatcher.dispatch(source_event.name, source_input,
        otp_app: alva_state(socket).otp_app,
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
    normalized = normalize_mount_config(config)

    # Make subscriptions available in socket.private for allowlist checking
    socket =
      Phoenix.LiveView.put_private(socket, :alva_options, subscriptions: normalized.subscriptions)

    otp_app = host_app_otp_app!(socket)
    registry = Alva.Registry.registry(otp_app)

    page_event_callbacks = page_event_callbacks!(normalized.page_events)
    ensure_page_events_do_not_shadow_dispatcher_events!(page_event_callbacks, registry)

    socket
    |> setup_initial_alva_state(normalized, params, otp_app, registry)
    |> eager_activate_mount_subscriptions(normalized.subscriptions, otp_app)
    |> configure_file_uploads_from_commands(config[:commands], otp_app)
    |> attach_alva_hooks(normalized, page_event_callbacks, otp_app)
    |> activate_initial_collections(normalized.collections)
    |> activate_initial_signals(normalized.signals)
    |> sync_projection_route_topics(normalized.route_subscriptions)
    |> sync_page_state(normalize_page_state_callback!(normalized.page_state))
    |> then(&{:cont, &1})
  end

  defp setup_initial_alva_state(socket, normalized, params, otp_app, registry) do
    route_params = normalize_route_params(params)
    collection_specs = collection_activation_specs(normalized.collections)
    route_change_collections = route_change_collection_specs(normalized.collections)

    update_alva(socket, fn state ->
      state
      |> Map.merge(projection_cache(registry))
      |> Map.merge(%{
        otp_app: otp_app,
        domains: registry.domains,
        collection_specs: collection_specs,
        route_params: route_params,
        route_change_collections: route_change_collections
      })
    end)
  end

  defp eager_activate_mount_subscriptions(socket, subscriptions, otp_app) do
    Enum.reduce(subscriptions, socket, fn
      {key, opts}, acc_sock ->
        if Keyword.get(opts, :activate) == :mount do
          case Alva.Registry.fetch_subscription_by_key(otp_app, key) do
            {:ok, resource, subscription} ->
              case apply(resource, subscription.resolve, [%{}, acc_sock]) do
                {:ok, resolution} ->
                  apply_subscription_resolution(acc_sock, subscription, resolution)

                _ ->
                  acc_sock
              end

            _ ->
              acc_sock
          end
        else
          acc_sock
        end

      _, acc_sock ->
        acc_sock
    end)
  end

  defp configure_file_uploads_from_commands(socket, commands, otp_app) do
    upload_arg_names =
      Enum.flat_map(commands || [], fn command_name ->
        case Alva.Registry.fetch_event(otp_app, to_string(command_name)) do
          {:ok, resource, event_def} ->
            action = Ash.Resource.Info.action(resource, event_def.action)

            if action do
              action.arguments
              |> Enum.filter(fn arg ->
                case arg.type do
                  Ash.Type.File -> true
                  {:array, Ash.Type.File} -> true
                  _ -> false
                end
              end)
              |> Enum.map(& &1.name)
            else
              []
            end

          _ ->
            []
        end
      end)
      |> Enum.uniq()

    Enum.reduce(upload_arg_names, socket, fn arg_name, acc_socket ->
      Phoenix.LiveView.allow_upload(acc_socket, arg_name, accept: :any, auto_upload: true)
    end)
  end

  defp attach_alva_hooks(socket, normalized, page_event_callbacks, otp_app) do
    socket
    |> attach_event_hook(page_event_callbacks, otp_app)
    |> attach_info_hook()
    |> attach_params_hook(normalized)
  end

  defp attach_event_hook(socket, page_event_callbacks, otp_app) do
    Phoenix.LiveView.attach_hook(socket, :alva_handle_event, :handle_event, fn event_name,
                                                                               params,
                                                                               sock ->
      cond do
        upload_lifecycle_event?(event_name) ->
          {:halt, sock}

        event_name == "alva:activate_subscription" ->
          handle_activate_subscription(params, sock, otp_app)

        event_name == "alva:load_more_subscription" ->
          handle_load_more_subscription(params, sock, otp_app)

        event_name == "alva:deactivate_subscription" ->
          handle_deactivate_subscription(params, sock, otp_app)

        Map.has_key?(page_event_callbacks, event_name) ->
          handle_page_event(page_event_callbacks, event_name, params, sock)

        true ->
          res = Alva.Dispatcher.dispatch(event_name, params, otp_app: otp_app, socket: sock)

          case res do
            %{ok: false, error: %{type: "unknown"}} ->
              {:cont, sock}

            _ ->
              {:halt, res, sock}
          end
      end
    end)
  end

  defp attach_info_hook(socket) do
    Phoenix.LiveView.attach_hook(socket, :alva_handle_info, :handle_info, fn
      %Ash.Notifier.Notification{} = notification, sock ->
        handle_notification(notification, sock, notification_occurrence_keys(notification))

      %Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{} = notification} = broadcast,
      sock ->
        _ = broadcast
        handle_notification(notification, sock, notification_occurrence_keys(notification))

      _msg, sock ->
        {:cont, sock}
    end)
  end

  defp attach_params_hook(socket, normalized) do
    route_change_collections = alva_state(socket).route_change_collections
    route_subscription_callbacks = callback_route_subscriptions?(normalized.route_subscriptions)
    page_state_callback = normalize_page_state_callback!(normalized.page_state)

    cond do
      map_size(route_change_collections) == 0 and not route_subscription_callbacks and
          is_nil(page_state_callback) ->
        socket

      map_size(route_change_collections) == 0 and route_subscription_callbacks and
        is_nil(page_state_callback) and not route_lifecycle_available?(socket) ->
        socket

      map_size(route_change_collections) == 0 and not route_subscription_callbacks and
        not is_nil(page_state_callback) and not route_lifecycle_available?(socket) ->
        socket

      true ->
        Phoenix.LiveView.attach_hook(socket, :alva_handle_params, :handle_params, fn
          params, _uri, sock ->
            sock =
              sock
              |> put_route_params(params)
              |> sync_projection_route_topics(normalized.route_subscriptions)
              |> refresh_route_change_collections()
              |> sync_page_state(page_state_callback)

            {:cont, sock}
        end)
    end
  end

  defp activate_initial_collections(socket, collections) do
    Enum.reduce(collections, socket, fn collection_spec, acc_socket ->
      {collection_name, opts} = normalize_collection_spec!(collection_spec)
      collection(acc_socket, collection_name, opts)
    end)
  end

  defp activate_initial_signals(socket, signals) do
    Enum.reduce(signals, socket, fn signal_name, acc_socket ->
      activate_signal(acc_socket, signal_name)
    end)
  end

  defp handle_notification(notification, sock, occurrence_keys) do
    matches =
      matching_projection_operations(sock, notification.resource, occurrence_keys)

    case matches do
      %{collections: [], signals: []} ->
        {:cont, sock}

      %{signals: signals} ->
        sock = apply_collection_operations(sock, matches, notification.data)

        if signals == [] do
          {:halt, sock}
        else
          {:halt, push_signals(sock, notification.data, signals)}
        end
    end
  end

  defp upload_lifecycle_event?(event_name)
       when event_name in [@upload_change_event, @upload_submit_event],
       do: true

  defp upload_lifecycle_event?(_event_name), do: false

  defp handle_page_event(page_event_callbacks, event_name, params, socket) do
    %{callback: callback, input_types: input_types} = Map.fetch!(page_event_callbacks, event_name)

    if is_nil(input_types) do
      callback
      |> resolve_page_event_callback!(socket, event_name, params)
      |> normalize_page_event_result!(event_name, callback)
    else
      changeset = Ecto.Changeset.cast({%{}, input_types}, params || %{}, Map.keys(input_types))

      if changeset.valid? do
        casted_params =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

        callback
        |> resolve_page_event_callback!(socket, event_name, casted_params)
        |> normalize_page_event_result!(event_name, callback)
      else
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)

        reply = %{
          ok: false,
          error: %{
            message: "Validation failed for page event #{event_name}",
            details: errors
          }
        }

        {:halt, reply, socket}
      end
    end
  end

  defp resolve_page_event_callback!(callback, %{view: view} = socket, event_name, params)
       when is_atom(view) and not is_nil(view) do
    if function_exported?(view, callback, 2) do
      apply(view, callback, [params, socket])
    else
      raise ArgumentError,
            "Alva page event #{inspect(event_name)} callback #{inspect(callback)} must be defined on #{inspect(view)} with arity 2"
    end
  end

  defp resolve_page_event_callback!(callback, _socket, event_name, _params) do
    raise ArgumentError,
          "Alva page event #{inspect(event_name)} callback #{inspect(callback)} requires socket.view to be set"
  end

  defp normalize_page_event_result!(
         {:reply, reply, %Phoenix.LiveView.Socket{} = socket},
         _event_name,
         _callback
       )
       when is_map(reply) do
    {:halt, reply, socket}
  end

  defp normalize_page_event_result!(result, event_name, callback) do
    raise ArgumentError,
          "Alva page event #{inspect(event_name)} callback #{inspect(callback)} must return {:reply, map, socket}, got: #{inspect(result)}"
  end

  defp ensure_page_events_do_not_shadow_dispatcher_events!(
         page_event_callbacks,
         %Alva.Registry{} = registry
       ) do
    Enum.each(Map.keys(page_event_callbacks), fn event_name ->
      if Map.has_key?(registry.event_map, event_name) do
        raise ArgumentError,
              "Alva page_events entry #{inspect(event_name)} collides with a host app dispatcher event. Page-owned events must use distinct browser event names and may dispatch Alva events from the callback."
      end
    end)
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

  defp active_collection_projections(socket) do
    active_projection_entries(socket, :collection_projections, :collections)
  end

  defp active_route_projections(socket) do
    active_collection_projections(socket)
    |> projection_names()
    |> Kernel.++(active_signal_projections(socket) |> projection_names())
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
    active_projection_entries(socket, :signal_projections, :signals)
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
      |> Enum.uniq()

    previously_owned_topics = collection_subscription_topics(socket)
    previous_topics = Map.get(previously_owned_topics, name, MapSet.new())
    next_topics = MapSet.union(previous_topics, MapSet.new(topics))

    socket =
      update_alva(socket, fn state ->
        collection_subscription_topics =
          Map.put(state.collection_subscription_topics, name, next_topics)

        %{state | collection_subscription_topics: collection_subscription_topics}
      end)

    if Phoenix.LiveView.connected?(socket) do
      Enum.reduce(MapSet.difference(next_topics, previous_topics), socket, fn topic, acc_socket ->
        if route_subscription_topic_owned?(acc_socket, topic) or
             collection_subscription_topic_owned?(previously_owned_topics, topic) do
          acc_socket
        else
          subscribe_transport_topic(acc_socket, topic)
        end
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
      if collection_subscription_topic_owned?(acc_socket, topic) do
        acc_socket
      else
        unsubscribe_transport_topic(acc_socket, topic)
      end
    end)
  end

  defp subscribe_projection_route_topics(socket, previous_topics, next_topics) do
    next_topics
    |> MapSet.difference(previous_topics)
    |> Enum.reduce(socket, fn topic, acc_socket ->
      if collection_subscription_topic_owned?(acc_socket, topic) do
        acc_socket
      else
        subscribe_transport_topic(acc_socket, topic)
      end
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

  defp subscribe_dynamic_topic(socket, topic) do
    state = alva_state(socket)
    refs = Map.get(state, :dynamic_subscription_refs, %{})
    count = Map.get(refs, topic, 0)

    socket =
      if count == 0 and not collection_subscription_topic_owned?(socket, topic) and
           not MapSet.member?(state.route_subscriptions, topic) do
        subscribe_transport_topic(socket, topic)
      else
        socket
      end

    update_alva(socket, fn state ->
      Map.put(state, :dynamic_subscription_refs, Map.put(refs, topic, count + 1))
    end)
  end

  defp unsubscribe_dynamic_topic(socket, topic) do
    state = alva_state(socket)
    refs = Map.get(state, :dynamic_subscription_refs, %{})
    count = Map.get(refs, topic, 0)

    if count > 0 do
      new_count = count - 1
      refs = if new_count == 0, do: Map.delete(refs, topic), else: Map.put(refs, topic, new_count)

      socket =
        update_alva(socket, fn state -> Map.put(state, :dynamic_subscription_refs, refs) end)

      if new_count == 0 and not collection_subscription_topic_owned?(socket, topic) and
           not MapSet.member?(state.route_subscriptions, topic) do
        unsubscribe_transport_topic(socket, topic)
      else
        socket
      end
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

  defp page_event_callbacks!(page_events) do
    page_events
    |> Enum.map(&normalize_page_event_spec!/1)
    |> Map.new()
  end

  defp normalize_page_state_callback!(nil), do: nil
  defp normalize_page_state_callback!(callback) when is_atom(callback), do: callback

  defp normalize_page_state_callback!(callback) do
    raise ArgumentError,
          "Alva declarative `page_state:` must be a local callback atom, got: #{inspect(callback)}"
  end

  defp sync_page_state(socket, nil), do: socket

  defp sync_page_state(socket, callback) when is_atom(callback) do
    page_state =
      callback
      |> resolve_page_state_callback!(socket)
      |> unwrap_page_state_callback_result!(callback)
      |> normalize_page_state!(callback)

    Phoenix.Component.assign(socket, page_state)
  end

  defp resolve_page_state_callback!(callback, %{view: view} = socket)
       when is_atom(view) and not is_nil(view) do
    cond do
      function_exported?(view, callback, 1) ->
        apply(view, callback, [socket])

      function_exported?(view, callback, 0) ->
        apply(view, callback, [])

      true ->
        raise ArgumentError,
              "Alva page_state callback #{inspect(callback)} is not defined on #{inspect(view)}"
    end
  end

  defp resolve_page_state_callback!(callback, _socket) do
    raise ArgumentError,
          "Alva page_state callback #{inspect(callback)} requires socket.view to be set"
  end

  defp unwrap_page_state_callback_result!({:ok, value}, _callback), do: value

  defp unwrap_page_state_callback_result!({:error, reason}, callback) do
    raise ArgumentError,
          "Alva page_state callback #{inspect(callback)} failed: #{inspect(reason)}"
  end

  defp unwrap_page_state_callback_result!(value, _callback), do: value

  defp normalize_page_state!(page_state, _callback) when is_map(page_state) do
    if Enum.all?(Map.keys(page_state), &is_atom/1) do
      page_state
    else
      raise_invalid_page_state!(:keys, page_state)
    end
  end

  defp normalize_page_state!(page_state, callback) do
    raise ArgumentError,
          "Alva page_state callback #{inspect(callback)} must return a map with atom keys, got: #{inspect(page_state)}"
  end

  defp raise_invalid_page_state!(:keys, page_state) do
    raise ArgumentError,
          "Alva page_state callbacks must return a map with atom keys, got: #{inspect(page_state)}"
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

  defp push_signals(socket, data, signals) do
    Enum.reduce(signals, socket, fn {_key, signal}, acc_socket ->
      Phoenix.LiveView.push_event(acc_socket, signal.name, signal_payload(data, signal))
    end)
  end

  defp signal_payload(data, signal) do
    {payload, meta} = Alva.Serializer.serialize(data, expose_metadata: signal.expose_metadata)

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

  defp apply_collection_operations(socket, %{collections: collections}, data) do
    Enum.reduce(collections, socket, fn {name, operation}, acc_socket ->
      apply_collection_operation(acc_socket, name, operation, data)
    end)
  end

  defp apply_collection_operation(socket, name, %{op: :delete}, data) do
    Phoenix.LiveView.stream_delete(socket, name, Alva.Serializer.strip_metadata(data))
  end

  defp apply_collection_operation(socket, name, %{op: :update} = operation, data) do
    Phoenix.LiveView.stream_insert(
      socket,
      name,
      Alva.Serializer.strip_metadata(data),
      collection_operation_opts(operation, update_only: true)
    )
  end

  defp apply_collection_operation(socket, name, %{op: :insert} = operation, data) do
    item = Alva.Serializer.strip_metadata(data)

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

  defp matching_projection_operations(socket, notification_resource, occurrence_keys) do
    otp_app = alva_state(socket).otp_app

    active_subscriptions =
      socket
      |> active_subscription_keys()
      |> Enum.flat_map(fn sub_key ->
        case Alva.Registry.fetch_subscription_by_key(otp_app, sub_key) do
          {:ok, resource, subscription} -> [{sub_key, {resource, subscription}}]
          :error -> []
        end
      end)

    sub_matches =
      Enum.reduce(active_subscriptions, %{streams: [], signals: []}, fn {name,
                                                                         {resource, subscription}},
                                                                        acc ->
        if resource == notification_resource do
          case subscription.kind do
            :stream ->
              stream_name = subscription_stream_name(subscription)

              ops =
                subscription.operations
                |> Enum.filter(&MapSet.member?(occurrence_keys, &1.on))
                |> Enum.map(&{stream_name, &1})

              %{acc | streams: ops ++ acc.streams}

            :signal ->
              if MapSet.member?(occurrence_keys, subscription.on) do
                %{acc | signals: [{name, subscription} | acc.signals]}
              else
                acc
              end

            _ ->
              acc
          end
        else
          acc
        end
      end)

    %{
      collections:
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
        |> Kernel.++(sub_matches.streams),
      signals:
        socket
        |> active_signal_projections()
        |> Enum.flat_map(fn {name, {resource, signal}} ->
          if resource == notification_resource and MapSet.member?(occurrence_keys, signal.on) do
            [{name, signal}]
          else
            []
          end
        end)
        |> Kernel.++(sub_matches.signals)
    }
  end

  defp active_projection_entries(socket, projection_key, active_key) do
    state = alva_state(socket)
    active_names = Map.fetch!(state, active_key)

    state
    |> Map.fetch!(projection_key)
    |> Enum.filter(fn {name, _projection} -> MapSet.member?(active_names, name) end)
  end

  defp projection_names(projections) do
    Enum.map(projections, fn {name, _projection} -> name end)
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
    state = alva_state(socket)

    projection =
      state
      |> projection_entries(kind)
      |> Enum.find_value(fn
        {^name, projection} -> projection
        _other -> nil
      end)

    case projection do
      nil ->
        raise ArgumentError,
              "Unknown Alva #{kind} projection #{inspect(name)} for host app registry #{inspect(state.otp_app)}"

      projection ->
        projection
    end
  end

  defp handle_activate_subscription(params, sock, otp_app) do
    case resolve_and_authorize_subscription(params, sock, otp_app) do
      {:ok, subscription, resolution} ->
        sock = apply_subscription_resolution(sock, subscription, resolution)
        client_resolution = Map.drop(resolution, [:items])
        {:halt, %{ok: true, data: client_resolution}, sock}

      {:error, reason} ->
        {:halt, %{ok: false, error: reason}, sock}
    end
  end

  defp apply_subscription_resolution(sock, subscription, resolution) do
    sock = activate_subscription_key(sock, subscription.key)
    stream_name = subscription_stream_name(subscription)

    # Subscribe to topics
    sock =
      if Phoenix.LiveView.connected?(sock) do
        Enum.reduce(resolution.topics || [], sock, fn topic, acc_sock ->
          subscribe_dynamic_topic(acc_sock, topic)
        end)
      else
        sock
      end

    # Stream items if it's a stream
    if subscription.kind == :stream do
      Phoenix.LiveView.stream(sock, stream_name, resolution.items || [], reset: true)
    else
      sock
    end
  end

  defp handle_load_more_subscription(params, sock, otp_app) do
    case resolve_and_authorize_subscription(params, sock, otp_app) do
      {:ok, subscription, resolution} ->
        sock =
          if subscription.kind == :stream do
            stream_name = subscription_stream_name(subscription)

            Enum.reduce(resolution.items || [], sock, fn item, acc_sock ->
              Phoenix.LiveView.stream_insert(acc_sock, stream_name, item)
            end)
          else
            sock
          end

        client_resolution = Map.drop(resolution, [:items])
        {:halt, %{ok: true, data: client_resolution}, sock}

      {:error, reason} ->
        {:halt, %{ok: false, error: reason}, sock}
    end
  end

  defp resolve_and_authorize_subscription(params, sock, otp_app) do
    subscription_name = params["name"]
    input = params["input"] || %{}

    with {:ok, resource, subscription} <-
           Alva.Registry.fetch_subscription(otp_app, subscription_name),
         :ok <- check_subscription_allowlist(sock, subscription.key),
         :ok <- check_subscription_authorization(sock, resource, subscription),
         {:ok, resolution} <- apply(resource, subscription.resolve, [input, sock]) do
      {:ok, subscription, resolution}
    else
      :error -> {:error, %{type: "not_found", message: "Resource not found"}}
      {:error, :forbidden} -> {:error, %{type: "forbidden", message: "Forbidden"}}
      {:error, reason} -> {:error, Alva.Error.format(reason)}
    end
  end

  defp handle_deactivate_subscription(params, sock, otp_app) do
    subscription_name = params["name"]
    input = params["input"] || %{}

    with {:ok, resource, subscription} <-
           Alva.Registry.fetch_subscription(otp_app, subscription_name),
         :ok <- check_subscription_allowlist(sock, subscription.key),
         {:ok, resolution} <- apply(resource, subscription.resolve, [input, sock]) do
      sock =
        if Phoenix.LiveView.connected?(sock) do
          Enum.reduce(resolution.topics || [], sock, fn topic, acc_sock ->
            unsubscribe_dynamic_topic(acc_sock, topic)
          end)
        else
          sock
        end
        |> deactivate_subscription_key(subscription.key)

      {:halt, %{ok: true}, sock}
    else
      _ ->
        {:halt, %{ok: false}, sock}
    end
  end

  defp check_subscription_allowlist(sock, subscription_key) do
    alva_options = Map.get(sock.private, :alva_options, [])
    allowlist = Keyword.get(alva_options, :subscriptions, [])

    normalized_allowlist =
      Enum.map(allowlist, fn
        {key, _opts} -> key
        key -> key
      end)

    if subscription_key in normalized_allowlist do
      :ok
    else
      {:error, :forbidden}
    end
  end

  defp check_subscription_authorization(sock, resource, subscription) do
    if subscription.authorize_with do
      actor = sock.assigns[:current_user] || sock.assigns[:current_actor]
      tenant = sock.assigns[:current_tenant]

      # Run authorization
      if Ash.can?({resource, subscription.authorize_with}, actor, tenant: tenant, maybe_is: false) do
        :ok
      else
        {:error, :forbidden}
      end
    else
      :ok
    end
  end

  defp activate_subscription_key(socket, key) when is_atom(key) do
    update_alva(socket, fn state ->
      refs = Map.get(state, :active_subscription_refs, %{})
      next_count = Map.get(refs, key, 0) + 1
      Map.put(state, :active_subscription_refs, Map.put(refs, key, next_count))
    end)
  end

  defp deactivate_subscription_key(socket, key) when is_atom(key) do
    update_alva(socket, fn state ->
      refs = Map.get(state, :active_subscription_refs, %{})

      next_refs =
        case Map.get(refs, key, 0) do
          count when count > 1 -> Map.put(refs, key, count - 1)
          1 -> Map.delete(refs, key)
          _ -> refs
        end

      Map.put(state, :active_subscription_refs, next_refs)
    end)
  end

  defp active_subscription_keys(socket) do
    socket
    |> alva_state()
    |> Map.get(:active_subscription_refs, %{})
    |> Map.keys()
  end

  defp subscription_stream_name(%{key: key, name: name}) when is_atom(key) and is_binary(name) do
    if Atom.to_string(key) == name, do: key, else: name
  end

  defp subscription_stream_name(%{key: key}), do: key

  defp projection_cache(%Alva.Registry{} = registry) do
    %{
      event_map: registry.event_map,
      collection_projections: Map.to_list(registry.collection_map),
      signal_projections: Map.to_list(registry.signal_map)
    }
  end

  defp projection_entries(state, :collection), do: state.collection_projections
  defp projection_entries(state, :signal), do: state.signal_projections

  defp find_resource_event_declaration!(resource, key) do
    event_projection =
      resource
      |> Alva.Registry.events()
      |> Enum.find(fn event -> event.key == key or event.name == key end)

    case event_projection do
      nil ->
        raise ArgumentError,
              "Unknown Alva event declaration #{inspect(key)} for resource #{inspect(resource)}"

      event_projection ->
        {resource, event_projection}
    end
  end

  defp normalize_mount_config(%{} = config) do
    validate_mount_config_keys!(config)
    collections = Map.get(config, :collections, [])
    signals = Map.get(config, :signals, [])

    validate_collection_activation_specs!(collections)
    validate_signal_activation_specs!(signals)
    validate_subscription_activation_specs!(Map.get(config, :subscriptions, []))
    validate_page_event_activation_specs!(Map.get(config, :page_events, []))
    validate_page_state_activation_spec!(Map.get(config, :page_state))
    validate_projection_namespace_activation_specs!(collections, signals)

    %{
      collections: collections,
      signals: signals,
      route_subscriptions: Map.get(config, :route_subscriptions, []),
      page_events: Map.get(config, :page_events, []),
      page_state: Map.get(config, :page_state),
      subscriptions: Map.get(config, :subscriptions, [])
    }
  end

  defp normalize_mount_config(config) when is_tuple(config) do
    raise ArgumentError,
          "Alva declarative page activation no longer supports legacy tuple mount config. Prefer keyword-form `use Alva.LiveView, subscriptions: [...]`; if you must use map form, pass :subscriptions and any legacy compatibility keys explicitly."
  end

  defp normalize_mount_config(config) when is_list(config) do
    if Keyword.keyword?(config) do
      raise ArgumentError,
            "Alva declarative page activation maps must be passed as a map, not a keyword list. Prefer keyword-form `use Alva.LiveView, subscriptions: [...]`; if you pass a map, include :subscriptions and any legacy compatibility keys explicitly."
    else
      raise ArgumentError,
            "Alva declarative page activation no longer accepts bare domain lists. Prefer keyword-form `use Alva.LiveView, subscriptions: [...]`; if you pass a map, include :subscriptions and any legacy compatibility keys explicitly."
    end
  end

  defp normalize_mount_config(config) do
    raise ArgumentError,
          "Alva declarative page activation must be configured with keyword-form `use Alva.LiveView, subscriptions: [...]` or a map containing :subscriptions plus any legacy compatibility keys you still need. Got: #{inspect(config)}"
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
          {:ok, collections} -> maybe_validate_collection_use_declarations!(collections, caller)
          :error -> {:known, []}
        end

      signals =
        case Keyword.fetch(opts, :signals) do
          {:ok, signals} -> maybe_validate_signal_use_declarations!(signals, caller)
          :error -> {:known, []}
        end

      case Keyword.fetch(opts, :subscriptions) do
        {:ok, subscriptions} ->
          maybe_validate_subscription_use_declarations!(subscriptions, caller)

        :error ->
          :ok
      end

      validate_projection_namespace_use_declarations!(collections, signals, caller)

      case Keyword.fetch(opts, :route_subscriptions) do
        {:ok, route_subscriptions} ->
          maybe_validate_route_subscription_use_declarations!(
            route_subscriptions,
            collections,
            signals,
            caller
          )

        :error ->
          :ok
      end

      case Keyword.fetch(opts, :page_events) do
        {:ok, page_events} ->
          maybe_validate_page_event_use_declarations!(page_events, caller)

        :error ->
          :ok
      end

      case Keyword.fetch(opts, :page_state) do
        {:ok, page_state} ->
          maybe_validate_page_state_use_declaration!(page_state, caller)

        :error ->
          :ok
      end
    else
      raise_compile_error!(caller, @err_opts_expected)
    end
  end

  defp validate_use_opts!(_opts, caller) do
    raise_compile_error!(caller, @err_opts_expected)
  end

  defp maybe_validate_collection_use_declarations!(collections, caller) do
    case expand_use_opt_literal(collections, caller) do
      {:ok, collections} -> {:known, validate_collection_use_declarations!(collections, caller)}
      :dynamic -> :unknown
    end
  end

  defp maybe_validate_signal_use_declarations!(signals, caller) do
    case expand_use_opt_literal(signals, caller) do
      {:ok, signals} -> {:known, validate_signal_use_declarations!(signals, caller)}
      :dynamic -> :unknown
    end
  end

  defp maybe_validate_subscription_use_declarations!(subscriptions, caller) do
    case expand_use_opt_literal(subscriptions, caller) do
      {:ok, subscriptions} -> validate_subscription_use_declarations!(subscriptions, caller)
      :dynamic -> :ok
    end
  end

  defp maybe_validate_route_subscription_use_declarations!(
         route_subscriptions,
         {:known, collections},
         {:known, signals},
         caller
       ) do
    case expand_use_opt_literal(route_subscriptions, caller) do
      {:ok, route_subscriptions} ->
        validate_route_subscription_use_declarations!(
          route_subscriptions,
          collections,
          signals,
          caller
        )

      :dynamic ->
        :ok
    end
  end

  defp maybe_validate_route_subscription_use_declarations!(
         _route_subscriptions,
         _collections,
         _signals,
         _caller
       ),
       do: :ok

  defp maybe_validate_page_event_use_declarations!(page_events, caller) do
    case expand_use_opt_literal(page_events, caller) do
      {:ok, page_events} -> validate_page_event_use_declarations!(page_events, caller)
      :dynamic -> :ok
    end
  end

  defp maybe_validate_page_state_use_declaration!(page_state, caller) do
    case expand_use_opt_literal(page_state, caller) do
      {:ok, page_state} -> validate_page_state_use_declaration!(page_state, caller)
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

  defp validate_public_activation_key!(:streams, caller) do
    raise_compile_error!(caller, @err_streams_removed)
  end

  defp validate_public_activation_key!(key, caller) do
    unless key in @public_activation_keys do
      raise_compile_error!(caller, err_unsupported_key(key))
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
          raise_compile_error!(
            caller,
            "Alva declarative `collections:` entries must be atoms or keyword entries like `collections: [sales_orders: [source_input: :callback]]`. Got: #{inspect(other)}"
          )
      end)

    validate_unique_activation_names!(names, :collection, caller)
    names
  end

  defp validate_collection_use_declarations!(_collections, caller) do
    raise_compile_error!(caller, "Alva declarative `collections:` must be a list.")
  end

  defp validate_collection_use_opts!(name, opts, caller) when is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise_compile_error!(caller, invalid_collection_use_opts_description(name))
    end

    Enum.each(Keyword.keys(opts), &validate_collection_use_opt_key!(&1, name, caller))
  end

  defp validate_collection_use_opts!(name, _opts, caller) do
    raise_compile_error!(caller, invalid_collection_use_opts_description(name))
  end

  defp validate_collection_use_opt_key!(:source_input, _name, _caller), do: :ok
  defp validate_collection_use_opt_key!(:reload_on, _name, _caller), do: :ok

  defp validate_collection_use_opt_key!(:params, name, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative collection #{inspect(name)} no longer accepts `params:`. Use `source_input:` instead."
    )
  end

  defp validate_collection_use_opt_key!(:subscriptions, name, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative collection #{inspect(name)} no longer accepts nested `subscriptions:`. Move topic wiring to top-level `route_subscriptions:`."
    )
  end

  defp validate_collection_use_opt_key!(key, name, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative collection #{inspect(name)} only accepts :source_input and :reload_on options. Unsupported option: #{inspect(key)}"
    )
  end

  defp validate_signal_use_declarations!(signals, caller) when is_list(signals) do
    keys =
      Enum.map(signals, fn
        key when is_atom(key) ->
          key

        name when is_binary(name) ->
          raise_compile_error!(
            caller,
            "Alva declarative `signals:` no longer accepts browser-facing string names like #{inspect(name)}. Use the signal declaration key atom instead."
          )

        {key, _opts} when is_atom(key) ->
          raise_compile_error!(
            caller,
            "Alva declarative `signals:` only accepts atom declaration keys. Remove tuple options for #{inspect(key)} and keep client-facing names in the resource declaration."
          )

        other ->
          raise_compile_error!(
            caller,
            "Alva declarative `signals:` entries must be atom declaration keys, got: #{inspect(other)}"
          )
      end)

    validate_unique_activation_names!(keys, :signal, caller)
    keys
  end

  defp validate_signal_use_declarations!(_signals, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative `signals:` must be a list of atom declaration keys."
    )
  end

  defp validate_subscription_use_declarations!(subscriptions, caller)
       when is_list(subscriptions) do
    keys =
      Enum.map(subscriptions, fn
        key when is_atom(key) ->
          key

        {key, opts} when is_atom(key) and is_list(opts) ->
          validate_subscription_use_opts!(key, opts, caller)
          key

        name when is_binary(name) ->
          raise_compile_error!(
            caller,
            "Alva declarative `subscriptions:` entries must use declaration key atoms, got browser-facing name #{inspect(name)}"
          )

        {key, _opts} ->
          raise_compile_error!(
            caller,
            invalid_subscription_use_entries_description("Invalid key: #{inspect(key)}")
          )

        other ->
          raise_compile_error!(
            caller,
            invalid_subscription_use_entries_description("Got: #{inspect(other)}")
          )
      end)

    validate_unique_activation_names!(keys, :subscription, caller)
    keys
  end

  defp validate_subscription_use_declarations!(_subscriptions, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative `subscriptions:` must be a list of declaration key atoms or keyword entries."
    )
  end

  defp validate_subscription_use_opts!(name, opts, caller) when is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise_compile_error!(caller, invalid_subscription_use_opts_description(name))
    end

    Enum.each(Keyword.keys(opts), &validate_subscription_use_opt_key!(&1, name, opts, caller))
  end

  defp validate_subscription_use_opts!(name, _opts, caller) do
    raise_compile_error!(caller, invalid_subscription_use_opts_description(name))
  end

  defp validate_subscription_use_opt_key!(:activate, name, opts, caller) do
    case Keyword.get(opts, :activate) do
      mode when mode in [:mount, :client] ->
        :ok

      mode ->
        raise_compile_error!(
          caller,
          "Alva declarative subscription #{inspect(name)} only accepts `activate: :mount` or `activate: :client`, got: #{inspect(mode)}"
        )
    end
  end

  defp validate_subscription_use_opt_key!(key, name, _opts, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative subscription #{inspect(name)} only accepts #{@public_subscription_option_keys |> inspect()}. Unsupported option: #{inspect(key)}"
    )
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

  defp validate_projection_namespace_use_declarations!(
         {:known, collections},
         {:known, signals},
         caller
       ) do
    collections
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(signals))
    |> Enum.each(fn key ->
      raise_compile_error!(
        caller,
        "Alva declarative page activation cannot activate the same projection key in both `collections:` and `signals:`: #{inspect(key)}"
      )
    end)
  end

  defp validate_projection_namespace_use_declarations!(_collections, _signals, _caller), do: :ok

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
            raise_compile_error!(
              caller,
              "Alva declarative route_subscriptions entry #{inspect(projection)} must reference an activated Collection or Signal projection on the same page."
            )
          end

          validate_route_subscription_use_topics!(projection, topics, caller)
          projection

        {projection, _topics} ->
          raise_compile_error!(
            caller,
            "Alva route_subscriptions keys must be Collection or Signal declaration key atoms, got: #{inspect(projection)}"
          )

        spec ->
          raise_compile_error!(
            caller,
            "Alva route_subscriptions entries must be {projection, topics} tuples, got: #{inspect(spec)}"
          )
      end)

    validate_unique_route_subscription_names!(projections, caller)
  end

  defp validate_route_subscription_use_declarations!(
         _route_subscriptions,
         _collections,
         _signals,
         caller
       ) do
    raise_compile_error!(
      caller,
      "Alva declarative `route_subscriptions:` must be a list of {projection, topics} tuples."
    )
  end

  defp validate_route_subscription_use_topics!(_projection, topic, _caller)
       when is_binary(topic) or is_atom(topic),
       do: :ok

  defp validate_route_subscription_use_topics!(projection, topics, caller) when is_list(topics) do
    if Enum.all?(topics, &is_binary/1) do
      :ok
    else
      raise_compile_error!(
        caller,
        invalid_route_subscription_topics_description(projection, topics)
      )
    end
  end

  defp validate_route_subscription_use_topics!(projection, topics, caller) do
    raise_compile_error!(
      caller,
      invalid_route_subscription_topics_description(projection, topics)
    )
  end

  defp validate_unique_route_subscription_names!(projections, caller) do
    projections
    |> Enum.frequencies()
    |> Enum.each(fn
      {_projection, 1} ->
        :ok

      {projection, _count} ->
        raise_compile_error!(
          caller,
          "Alva route_subscriptions contains duplicate entries for #{inspect(projection)}"
        )
    end)
  end

  defp normalize_page_event_use_spec!(page_event, caller) do
    {event_name, callback} = page_event_use_tuple!(page_event, caller)
    validate_page_event_use_name!(event_name, caller)
    validate_page_event_use_callback!(event_name, callback, caller)
    event_name
  end

  defp page_event_use_tuple!({:{}, _, [event_name, callback | _rest]}, _caller),
    do: {event_name, callback}

  defp page_event_use_tuple!({event_name, callback}, _caller), do: {event_name, callback}
  defp page_event_use_tuple!({event_name, callback, _types}, _caller), do: {event_name, callback}

  defp page_event_use_tuple!(other, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative page_events entries must be {event_name, callback} or {event_name, callback, types} tuples. Got: #{inspect(other)}"
    )
  end

  defp validate_page_event_use_name!(event_name, _caller) when is_binary(event_name), do: :ok

  defp validate_page_event_use_name!(event_name, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative page_events event names must be binaries, got: #{inspect(event_name)}"
    )
  end

  defp validate_page_event_use_callback!(_event_name, callback, _caller) when is_atom(callback),
    do: :ok

  defp validate_page_event_use_callback!(event_name, callback, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative page_events callback for #{inspect(event_name)} must be a local callback atom, got: #{inspect(callback)}"
    )
  end

  defp validate_page_event_use_declarations!(page_events, caller) when is_list(page_events) do
    event_names = Enum.map(page_events, &normalize_page_event_use_spec!(&1, caller))

    validate_unique_page_event_use_names!(event_names, caller)
  end

  defp validate_page_event_use_declarations!(_page_events, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative `page_events:` must be a list of {event_name, callback} tuples."
    )
  end

  defp validate_unique_page_event_use_names!(event_names, caller) do
    event_names
    |> Enum.frequencies()
    |> Enum.each(fn
      {_event_name, 1} ->
        :ok

      {event_name, _count} ->
        raise_compile_error!(
          caller,
          "Alva declarative page_events contains duplicate entries for #{inspect(event_name)}"
        )
    end)
  end

  defp validate_page_state_use_declaration!(callback, _caller) when is_atom(callback), do: :ok

  defp validate_page_state_use_declaration!(callback, caller) do
    raise_compile_error!(
      caller,
      "Alva declarative `page_state:` must be a local callback atom, got: #{inspect(callback)}"
    )
  end

  defp invalid_collection_use_opts_description(name) do
    "Alva declarative collection #{inspect(name)} options must be a keyword list containing only :source_input and :reload_on."
  end

  defp invalid_subscription_use_entries_description(detail) do
    "Alva declarative `subscriptions:` entries must be atoms or keyword entries like `subscriptions: [sales_orders: [activate: :mount]]`. #{detail}"
  end

  defp invalid_subscription_use_opts_description(name) do
    "Alva declarative subscription #{inspect(name)} options must be a keyword list containing only #{@public_subscription_option_keys |> inspect()}."
  end

  defp invalid_route_subscription_topics_description(projection, topics) do
    "Alva route_subscriptions entry #{inspect(projection)} must provide a binary topic or list of binary topics, got: #{inspect(topics)}"
  end

  defp raise_compile_error!(caller, description) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description: description
  end

  defp validate_mount_config_keys!(config) do
    config
    |> Map.keys()
    |> Enum.each(fn
      :domains ->
        raise ArgumentError, @err_domains_removed

      :collections ->
        :ok

      :signals ->
        :ok

      :route_subscriptions ->
        :ok

      :subscriptions ->
        :ok

      :page_events ->
        :ok

      :page_state ->
        :ok

      :streams ->
        raise ArgumentError, @err_streams_removed

      key ->
        unless key in @public_activation_keys do
          raise ArgumentError,
                err_unsupported_key(key)
        end
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

  defp validate_subscription_activation_specs!(subscriptions) when is_list(subscriptions) do
    keys =
      Enum.map(subscriptions, fn
        key when is_atom(key) ->
          key

        {key, opts} when is_atom(key) and is_list(opts) ->
          validate_subscription_activation_opts!(key, opts)
          key

        name when is_binary(name) ->
          raise ArgumentError,
                "Alva declarative `subscriptions:` entries must use declaration key atoms, got browser-facing name #{inspect(name)}"

        {key, _opts} ->
          raise ArgumentError,
                "Alva declarative `subscriptions:` entries must be atoms or keyword entries like `subscriptions: [sales_orders: [activate: :mount]]`. Invalid key: #{inspect(key)}"

        other ->
          raise ArgumentError,
                "Alva declarative `subscriptions:` entries must be atoms or keyword entries like `subscriptions: [sales_orders: [activate: :mount]]`, got: #{inspect(other)}"
      end)

    validate_unique_activation_specs!(keys, :subscription)
  end

  defp validate_subscription_activation_specs!(subscriptions) do
    raise ArgumentError,
          "Alva declarative `subscriptions:` must be a list of declaration key atoms or keyword entries, got: #{inspect(subscriptions)}"
  end

  defp validate_subscription_activation_opts!(name, opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "Alva declarative subscription #{inspect(name)} options must be a keyword list containing only #{@public_subscription_option_keys |> inspect()}."
    end

    Enum.each(Keyword.keys(opts), fn
      :activate ->
        case Keyword.get(opts, :activate) do
          mode when mode in [:mount, :client] ->
            :ok

          mode ->
            raise ArgumentError,
                  "Alva declarative subscription #{inspect(name)} only accepts `activate: :mount` or `activate: :client`, got: #{inspect(mode)}"
        end

      key ->
        raise ArgumentError,
              "Alva declarative subscription #{inspect(name)} only accepts #{@public_subscription_option_keys |> inspect()}. Unsupported option: #{inspect(key)}"
    end)
  end

  defp validate_page_event_activation_specs!(page_events) when is_list(page_events) do
    event_names =
      page_events
      |> Enum.map(&normalize_page_event_spec!/1)
      |> Enum.map(&elem(&1, 0))

    validate_unique_page_event_activation_specs!(event_names)
  end

  defp validate_page_event_activation_specs!(page_events) do
    raise ArgumentError,
          "Alva declarative `page_events:` must be a list of {event_name, callback} tuples, got: #{inspect(page_events)}"
  end

  defp validate_page_state_activation_spec!(nil), do: :ok
  defp validate_page_state_activation_spec!(callback) when is_atom(callback), do: :ok

  defp validate_page_state_activation_spec!(callback) do
    raise ArgumentError,
          "Alva declarative `page_state:` must be a local callback atom, got: #{inspect(callback)}"
  end

  defp normalize_page_event_spec!({event_name, callback}) when is_binary(event_name) do
    normalize_page_event_spec!({event_name, callback, nil})
  end

  defp normalize_page_event_spec!({event_name, callback, input_types})
       when is_binary(event_name) and is_atom(callback) and
              (is_map(input_types) or is_nil(input_types)) do
    {event_name, %{callback: callback, input_types: input_types}}
  end

  defp normalize_page_event_spec!({event_name, callback, _types}) when is_binary(event_name) do
    raise ArgumentError,
          "Alva page_events callback for #{inspect(event_name)} must be a local callback atom, got: #{inspect(callback)}"
  end

  defp normalize_page_event_spec!({event_name, _callback}) do
    raise ArgumentError,
          "Alva page_events event names must be binaries, got: #{inspect(event_name)}"
  end

  defp normalize_page_event_spec!(page_event) do
    raise ArgumentError,
          "Alva page_events entries must be {event_name, callback} or {event_name, callback, input_types} tuples like {\"support.join_chat\", :join_chat_page_event, %{customer_name: :string}}, got: #{inspect(page_event)}"
  end

  defp validate_unique_page_event_activation_specs!(event_names) do
    event_names
    |> Enum.frequencies()
    |> Enum.each(fn
      {_event_name, 1} ->
        :ok

      {event_name, _count} ->
        raise ArgumentError,
              "Alva declarative page_events contains duplicate entries for #{inspect(event_name)}"
    end)
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

  defp route_subscription_topic_owned?(socket, topic) do
    socket
    |> alva_state()
    |> Map.fetch!(:route_subscriptions)
    |> MapSet.member?(topic)
  end

  defp collection_subscription_topic_owned?(%{private: _} = socket, topic) do
    socket
    |> collection_subscription_topics()
    |> collection_subscription_topic_owned?(topic)
  end

  defp collection_subscription_topic_owned?(collection_topics, topic)
       when is_map(collection_topics) do
    collection_topics
    |> Map.values()
    |> Enum.any?(&MapSet.member?(&1, topic))
  end

  defp collection_subscription_topics(socket) do
    socket
    |> alva_state()
    |> Map.get(:collection_subscription_topics, %{})
  end

  defp alva_state(socket) do
    Map.get(socket.private, @alva_private_key, %{
      otp_app: nil,
      domains: [],
      event_map: %{},
      collection_projections: [],
      signal_projections: [],
      collection_specs: %{},
      collection_subscription_topics: %{},
      route_subscriptions: MapSet.new(),
      route_params: %{},
      route_change_collections: %{},
      collections: MapSet.new(),
      collection_source_inputs: %{},
      signals: MapSet.new(),
      active_subscription_refs: %{}
    })
  end
end
