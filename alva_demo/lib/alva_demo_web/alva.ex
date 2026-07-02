defmodule AlvaDemoWeb.Alva do


  def dispatch("students.archive", %{"id" => id}, socket) do
    case AlvaDemo.Academics.Student.by_id(id) do
      {:ok, student} ->
        case AlvaDemo.Academics.Student.archive(student) do
          {:ok, record} ->
            {:reply, %{ok: true, data: Alva.Dispatcher.strip_metadata(record)}, socket}

          {:error, error} ->
            {:reply, %{ok: false, error: Alva.Error.format(error)}, socket}
        end

      {:error, error} ->
        {:reply, %{ok: false, error: Alva.Error.format(error)}, socket}
    end
  end

  def dispatch(event, params, socket) do
    result = Alva.Dispatcher.dispatch(event, params, domains: [AlvaDemo.Academics])
    {:reply, result, socket}
  end
end
