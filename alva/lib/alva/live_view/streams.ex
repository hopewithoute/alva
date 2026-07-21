defmodule Alva.LiveView.Streams do
  @moduledoc false

  alias Alva.LiveView.State
  alias Alva.LiveView.Sync
  alias Ash.Resource.Info

  @spec reconfigure_streams(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def reconfigure_streams(socket, params \\ %{}) do
    state = State.get(socket)

    Enum.reduce(state.streams || %{}, socket, fn {name, stream_meta}, acc_socket ->
      config = [
        resource: stream_meta.resource,
        source: stream_meta.source,
        scope: Map.get(stream_meta, :scope, %{}),
        sync_on: stream_meta.sync_on,
        reset: true
      ]

      configure_stream(acc_socket, name, config, params, state.otp_app)
    end)
  end

  @spec configure_streams(Phoenix.LiveView.Socket.t(), Keyword.t() | map(), map(), atom()) ::
          Phoenix.LiveView.Socket.t()
  def configure_streams(socket, streams_config, params, otp_app) do
    Enum.reduce(streams_config, socket, fn {name, config}, acc_socket ->
      configure_stream(acc_socket, name, config, params, otp_app)
    end)
  end

  defp configure_stream(socket, name, config, params, _otp_app) do
    resource = Keyword.fetch!(config, :resource)
    source = Keyword.fetch!(config, :source)
    scope_def = Keyword.get(config, :scope, %{})
    sync_on = Keyword.get(config, :sync_on, [])
    reset = Keyword.get(config, :reset, false)

    scope_args =
      Map.new(scope_def, fn {arg_name, assign_key} ->
        value = Map.get(socket.assigns, assign_key) || Map.get(params, to_string(assign_key))
        {arg_name, value}
      end)

    socket
    |> load_stream_data(name, resource, source, scope_args, reset)
    |> setup_stream_pubsub(resource, sync_on, scope_args)
    |> register_stream_meta(name, resource, source, scope_def, scope_args, sync_on)
  end

  @spec load_stream_data(
          Phoenix.LiveView.Socket.t(),
          atom() | String.t(),
          module(),
          atom(),
          map(),
          boolean()
        ) :: Phoenix.LiveView.Socket.t()
  def load_stream_data(socket, name, resource, source, scope_args, reset) do
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

    Phoenix.LiveView.stream(socket, name, records, reset: reset)
  end

  defp setup_stream_pubsub(socket, resource, sync_on, scope_args) do
    if Info.notifiers(resource) |> Enum.member?(Ash.Notifier.PubSub) do
      topics = Sync.pubsub_topics(resource, sync_on, scope_args)
      pubsub = endpoint_pubsub!(socket)
      Enum.each(topics, &Phoenix.PubSub.subscribe(pubsub, &1))
      socket
    else
      socket
    end
  end

  defp register_stream_meta(socket, name, resource, source, scope_def, scope_args, sync_on) do
    State.update(socket, fn state ->
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

  @spec apply_stream_operations(Phoenix.LiveView.Socket.t(), map(), struct() | map()) ::
          Phoenix.LiveView.Socket.t()
  def apply_stream_operations(socket, streams, data) do
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

  defp record_in_scope?(socket, stream_meta, record) do
    resource = stream_meta.resource
    primary_keys = Info.primary_key(resource)
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
