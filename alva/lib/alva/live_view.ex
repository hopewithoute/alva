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
    :commands
  ]
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
      @alva_subscriptions Keyword.get(unquote(opts), :subscriptions, [])
      @alva_commands Keyword.get(unquote(opts), :commands, [])
      @alva_subscriptions Keyword.get(unquote(opts), :subscriptions, [])
      @alva_commands Keyword.get(unquote(opts), :commands, [])

      on_mount({Alva.LiveView, %{subscriptions: @alva_subscriptions, commands: @alva_commands}})
    end
  end

  def on_mount(config, _params, _session, socket) do
    subscriptions = Map.get(config, :subscriptions, [])
    commands = Map.get(config, :commands, [])
    socket = Phoenix.LiveView.put_private(socket, :alva_options, subscriptions: subscriptions)

    otp_app = host_app_otp_app!(socket)
    registry = Alva.Registry.registry(otp_app)

    socket
    |> setup_initial_alva_state(otp_app, registry)
    |> eager_activate_mount_subscriptions(subscriptions, otp_app)
    |> configure_file_uploads_from_commands(commands, otp_app)
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

        event_name == "alva:activate_subscription" ->
          handle_activate_subscription(params, sock, otp_app)

        event_name == "alva:load_more_subscription" ->
          handle_load_more_subscription(params, sock, otp_app)

        event_name == "alva:deactivate_subscription" ->
          handle_deactivate_subscription(params, sock, otp_app)

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

  defp handle_notification(notification, sock, occurrence_keys) do
    matches =
      matching_projection_operations(sock, notification.resource, occurrence_keys)

    case matches do
      %{streams: [], signals: []} ->
        {:cont, sock}

      %{signals: signals, streams: streams} ->
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
    Phoenix.LiveView.stream_insert(
      socket,
      name,
      Alva.Serializer.strip_metadata(data),
      stream_operation_opts(operation, update_only: true)
    )
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
      _other -> false
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
      if count == 0 do
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

      if new_count == 0 do
        unsubscribe_transport_topic(socket, topic)
      else
        socket
      end
    else
      socket
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
      event_map: registry.event_map
    }
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
