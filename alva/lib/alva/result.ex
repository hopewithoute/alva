defmodule Alva.Result do
  @moduledoc since: "0.1.0"
  @moduledoc """
  Applies LiveView-specific side effects to the socket based on the result
  of an `Alva.Dispatcher.dispatch/3` call and a requested strategy.

  ## Supported Strategies

    * `{:stream_insert, key}` - Inserts data into a `Phoenix.LiveView` stream.
    * `{:stream_delete, key}` - Deletes data from a `Phoenix.LiveView` stream.
    * `{:assign, key}` - Assigns data to the socket.
    * `{:push_event, event_name}` - Pushes a `Phoenix.LiveView` event to the client.
    * `{:navigate, to}` - Navigates to a new LiveView path.
    * `{:patch, to}` - Patches the current LiveView path.
    * `{:custom, module}` - Delegates to a custom module's `handle_result/2`.
    * `{:reply, :data}` - Default. Returns data without side effects.
  """

  @doc """
  Transforms the dispatcher result into a LiveView return tuple `{:reply, map, socket}`
  and applies the specified side effect to the socket.

  ## Examples

      iex> result = %{ok: true, data: %{id: 1, name: "Test"}}
      iex> Alva.Result.apply(result, socket, strategy: {:stream_insert, :students})
      {:reply, %{ok: true, data: %{id: 1, name: "Test"}}, socket_with_stream_inserted}

  """
  def apply(result, socket, opts \\ [])

  def apply(%{ok: true, data: data} = result, %Phoenix.LiveView.Socket{} = socket, opts)
      when not is_nil(data) do
    strategy = Keyword.get(opts, :strategy, {:reply, :data})

    socket = apply_strategy(strategy, socket, data)
    {:reply, result, socket}
  end

  def apply(result, socket, _opts) do
    {:reply, result, socket}
  end

  defp apply_strategy({:stream_insert, key}, socket, data) do
    Phoenix.LiveView.stream_insert(socket, key, data)
  end

  defp apply_strategy({:stream_delete, key}, socket, data) do
    Phoenix.LiveView.stream_delete(socket, key, data)
  end

  defp apply_strategy({:assign, key}, socket, data) do
    Phoenix.Component.assign(socket, key, data)
  end

  defp apply_strategy({:push_event, event_name}, socket, data) do
    Phoenix.LiveView.push_event(socket, event_name, data)
  end

  defp apply_strategy({:navigate, to}, socket, _data) when is_binary(to) do
    Phoenix.LiveView.push_navigate(socket, to: to)
  end

  defp apply_strategy({:patch, to}, socket, _data) when is_binary(to) do
    Phoenix.LiveView.push_patch(socket, to: to)
  end

  defp apply_strategy({:custom, module}, socket, data) do
    case module.handle_result(socket, data) do
      %Phoenix.LiveView.Socket{} = returned_socket ->
        returned_socket

      {:noreply, returned_socket} ->
        returned_socket

      _ ->
        raise ArgumentError,
              "Custom module #{inspect(module)}.handle_result/2 must return a Phoenix.LiveView.Socket or {:noreply, socket}"
    end
  end

  defp apply_strategy(_, socket, _data) do
    socket
  end
end
