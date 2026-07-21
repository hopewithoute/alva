defmodule Alva.LiveView.Sync do
  @moduledoc false

  alias Alva.LiveView.State
  alias Alva.LiveView.Streams
  alias Alva.LiveView.Uploads
  alias Ash.Changeset
  alias Ash.Notifier.PubSub.Info, as: PubSubInfo

  @spec attach_alva_hooks(Phoenix.LiveView.Socket.t(), atom()) :: Phoenix.LiveView.Socket.t()
  def attach_alva_hooks(socket, otp_app) do
    socket
    |> attach_event_hook(otp_app)
    |> attach_info_hook()
  end

  defp attach_event_hook(socket, otp_app) do
    Phoenix.LiveView.attach_hook(socket, :alva_handle_event, :handle_event, fn event_name,
                                                                               params,
                                                                               sock ->
      cond do
        Uploads.upload_lifecycle_event?(event_name) ->
          {:halt, sock}

        event_name == "alva:subscribe_signal" ->
          handle_subscribe_signal(params, sock, otp_app)

        event_name == "alva:unsubscribe_signal" ->
          handle_unsubscribe_signal(params, sock, otp_app)

        true ->
          {actor, tenant} = socket_actor_tenant(sock)

          {params, cleanup_paths} =
            case Alva.Registry.fetch_event(otp_app, event_name) do
              {:ok, resource, event_def} ->
                action = Ash.Resource.Info.action(resource, event_def.action)

                if action do
                  Uploads.consume_uploads_into_params(sock, action, params, otp_app: otp_app)
                else
                  {params, []}
                end

              _ ->
                {params, []}
            end

          try do
            res =
              Alva.Dispatcher.dispatch(event_name, params,
                actor: actor,
                tenant: tenant,
                otp_app: otp_app
              )

            handle_dispatch_result(res, sock)
          after
            Uploads.cleanup_persisted_uploads(cleanup_paths)
          end
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
      sock = Streams.apply_stream_operations(sock, streams, notification.data)

      if signals == [] do
        {:halt, sock}
      else
        {:halt, push_signals(sock, notification.data, signals)}
      end
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
    state = State.get(socket)

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

    state = State.get(sock)
    active_signals = Map.get(state, :active_signals, %{})

    sock =
      if Map.has_key?(active_signals, signal_name) do
        {:halt, _reply, sock} = handle_unsubscribe_signal(%{"name" => signal_name}, sock, nil)
        sock
      else
        sock
      end

    maybe_subscribe_to_topics(sock, topics)

    State.update(sock, fn state ->
      active_signals = Map.get(state, :active_signals, %{})
      signal_meta = %{resource: resource, signal: signal, topics: topics, params: payload}
      Map.put(state, :active_signals, Map.put(active_signals, signal_name, signal_meta))
    end)
  end

  defp build_authorization_subject(resource, action, payload) do
    case action.type do
      :read -> Ash.Query.for_read(resource, action.name, payload)
      :create -> Changeset.for_create(resource, action.name, payload)
      :update -> Changeset.for_update(resource, action.name, payload)
      :destroy -> Changeset.for_destroy(resource, action.name, payload)
      :action -> Ash.ActionInput.for_action(resource, action.name, payload)
    end
  end

  defp all_active_topics(active_signals) do
    Enum.flat_map(active_signals, fn {_, meta} -> Map.get(meta, :topics, []) end) |> MapSet.new()
  end

  defp maybe_subscribe_to_topics(sock, topics) do
    if Phoenix.LiveView.connected?(sock) do
      state = State.get(sock)
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
    state = State.get(sock)
    active_signals = Map.get(state, :active_signals, %{})
    topics_to_remove = Map.get(active_signals, signal_name, %{}) |> Map.get(:topics, [])

    active_signals = Map.delete(active_signals, signal_name)

    sock =
      State.update(sock, fn state ->
        Map.put(state, :active_signals, active_signals)
      end)

    if Phoenix.LiveView.connected?(sock) do
      remaining_signal_topics = all_active_topics(active_signals)
      stream_topics = all_stream_topics(State.get(sock))
      protected_topics = MapSet.union(remaining_signal_topics, stream_topics)
      pubsub = endpoint_pubsub!(sock)

      topics_to_remove
      |> Enum.reject(&MapSet.member?(protected_topics, &1))
      |> Enum.each(&Phoenix.PubSub.unsubscribe(pubsub, &1))
    end

    {:halt, %{ok: true}, sock}
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
    |> PubSubInfo.publications()
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

  @spec pubsub_topics(module(), list(atom()), map()) :: list(String.t())
  def pubsub_topics(resource, actions, payload) do
    prefix = PubSubInfo.prefix(resource) || ""
    delimiter = PubSubInfo.delimiter(resource)

    PubSubInfo.publications(resource)
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

  defp endpoint_pubsub!(%{endpoint: endpoint}) when is_atom(endpoint) and not is_nil(endpoint) do
    endpoint.config(:pubsub_server) ||
      raise ArgumentError,
            "Alva.LiveView realtime subscription transport requires a socket endpoint with :pubsub_server"
  end

  defp endpoint_pubsub!(_socket) do
    raise ArgumentError,
          "Alva.LiveView realtime subscription transport requires socket.endpoint to be set"
  end
end
