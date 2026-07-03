defmodule Alva.LiveView do
  @moduledoc """
  A macro to inject Alva-specific functionality into Phoenix LiveViews.
  """

  @alva_private_key :alva

  defmacro __using__(opts) do
    quote do
      import Alva.LiveView
      @alva_domains Keyword.get(unquote(opts), :domains, [])
      on_mount({Alva.LiveView, @alva_domains})
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

  def on_mount(domains, _params, _session, socket) do
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
          Phoenix.LiveView.allow_upload(s, arg.name, accept: :any)
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
            sock = apply_stream_query(sock, event_name, res)
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

  defp apply_stream_query_binding(socket, %{stream: stream_name, mode: :reset} = binding, data) do
    Phoenix.LiveView.stream(socket, stream_name, stream_query_items(data),
      reset: true,
      limit: binding.limit
    )
  end

  defp apply_stream_query_binding(socket, binding, data) do
    data
    |> stream_query_items()
    |> Enum.reduce(socket, fn item, acc_socket ->
      Phoenix.LiveView.stream_insert(acc_socket, binding.stream, item,
        at: stream_query_at(binding.mode),
        limit: binding.limit
      )
    end)
  end

  defp stream_query_items(nil), do: []
  defp stream_query_items(items) when is_list(items), do: items
  defp stream_query_items(item), do: [item]

  defp stream_query_at(:prepend), do: 0
  defp stream_query_at(:append), do: -1

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
        Phoenix.LiveView.stream_insert(acc_socket, name, data)

      {name, :update}, acc_socket ->
        Phoenix.LiveView.stream_insert(acc_socket, name, data)

      {name, :delete}, acc_socket ->
        Phoenix.LiveView.stream_delete(acc_socket, name, data)
    end)
  end

  defp stream_projection_matches?(
         {_name, {resource, stream}},
         notification_resource,
         events
       ) do
    resource == notification_resource and
      Enum.any?(stream.operations, &MapSet.member?(events, &1.on))
  end

  defp ensure_projection!(socket, kind, name) do
    domains = alva_state(socket).domains

    exists? =
      Enum.any?(domains, fn domain ->
        domain
        |> projection_map(kind)
        |> Map.has_key?(name)
      end)

    unless exists? do
      raise ArgumentError,
            "Unknown Alva #{kind} projection #{inspect(name)} for mounted domains #{inspect(domains)}"
    end
  end

  defp projection_map(domain, :stream), do: Alva.Domain.Info.alva_stream_map(domain)
  defp projection_map(domain, :signal), do: Alva.Domain.Info.alva_signal_map(domain)

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
      signals: MapSet.new(),
      stream_queries: %{}
    })
  end
end
