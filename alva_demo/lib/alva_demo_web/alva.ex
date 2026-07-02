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
        {:reply, %{ok: false, error: format_error(error)}, socket}
    end
  end

  def dispatch(event, _params, socket) do
    Logger.warning("Alva Dispatcher: Unknown event #{event}")
    {:reply, %{ok: false, error: %{type: "unknown", message: "Unknown event: #{event}"}}, socket}
  end

  defp format_error(%Ash.Error.Invalid{} = error) do
    fields =
      error.errors
      |> Enum.reduce(%{}, fn
        %{field: field} = sub_error, acc when not is_nil(field) ->
          clean_error = if Map.has_key?(sub_error, :bread_crumbs), do: %{sub_error | bread_crumbs: []}, else: sub_error
          msg = String.trim(Exception.message(clean_error))
          
          # sometimes it prefixes with "attribute " or similar, we can clean it if we want
          # but let's just return the message
          msg = Regex.replace(~r/^(attribute|argument)\s+#{field}\s+/i, msg, "")
          
          Map.update(acc, field, [msg], &[msg | &1])

        _, acc ->
          acc
      end)

    %{
      type: "validation",
      message: "Validation failed",
      fields: fields
    }
  end

  defp format_error(error) do
    %{
      type: "unknown",
      message: Exception.message(error)
    }
  end

  defp serialize(record) do
    record
    |> Map.from_struct()
    |> Map.drop([:__meta__, :__struct__])
  end
end
