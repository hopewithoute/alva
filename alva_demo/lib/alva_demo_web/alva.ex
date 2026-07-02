defmodule AlvaDemoWeb.Alva do
  def dispatch(event, params, socket) do
    result = Alva.Dispatcher.dispatch(event, params, domains: [AlvaDemo.Academics])
    strategy = get_strategy(event)
    Alva.Result.apply(result, socket, strategy: strategy)
  end

  defp get_strategy("students.create"), do: {:stream_insert, :students}
  defp get_strategy("students.archive"), do: {:stream_delete, :students}
  defp get_strategy("test.assign"), do: {:assign, :dummy_key}
  defp get_strategy(_), do: {:reply, :data}
end
