defmodule Alva.Result do
  @moduledoc """
  Applies LiveView-specific side effects to the socket based on the result
  of an Alva.Dispatcher.dispatch/3 call and a requested strategy.
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

  defp apply_strategy(_, socket, _data) do
    socket
  end
end
