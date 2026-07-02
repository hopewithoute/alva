defmodule AlvaDemoWeb.Alva do
  require Logger

  def dispatch("students.list", _params, socket) do
    data = 
      AlvaDemo.Academics.Student.read!()
      |> Enum.map(&serialize/1)

    {:reply, %{ok: true, data: data}, socket}
  end

  def dispatch("students.create", params, socket) do
    case AlvaDemo.Academics.Student.create(params) do
      {:ok, record} ->
        {:reply, %{ok: true, data: serialize(record)}, socket}

      {:error, error} ->
        {:reply, %{ok: false, error: %{message: Exception.message(error)}}, socket}
    end
  end

  def dispatch(event, _params, socket) do
    Logger.warning("Alva Dispatcher: Unknown event #{event}")
    {:reply, %{ok: false, error: %{type: "unknown", message: "Unknown event: #{event}"}}, socket}
  end

  defp serialize(record) do
    record
    |> Map.from_struct()
    |> Map.drop([:__meta__, :__struct__])
  end
end
