defmodule Alva.Error do
  @moduledoc since: "0.1.0"
  @moduledoc """
  Normalizes Ash errors into a standard format consumed by the Vue frontend.

  Error types produced by `format/2`:

    * `"not_found"` - The requested resource was not found.
    * `"validation"` - One or more fields failed validation. Includes a `fields` map
      with field-name keys and string-array values.
    * `"conflict"` - A global (non-field) conflict error with a `code` key.
    * `"forbidden"` - The actor is not authorized for the action.
    * `"unknown"` - An unhandled error. In dev/test, includes `details` with the
      formatted stacktrace. In production, returns a generic message.

  Configuration:

    * `:alva, :expose_unknown_errors` - Set to `true` to expose error details in production.
      Defaults to `true` in dev/test, `false` in prod.
  """

  @doc """
  Formats an Ash error into a standardized map for the frontend.

  Accepts any Ash error struct and returns a map with `:type`, `:message`,
  and optionally `:fields` or `:details`.
  """
  @doc since: "0.1.0"
  def format(error, stacktrace \\ nil)

  def format(%Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}, _stacktrace),
    do: not_found()

  def format(%Ash.Error.Query.NotFound{}, _stacktrace), do: not_found()

  def format(%Ash.Error.Invalid{} = error, _stacktrace) do
    case find_conflict(error.errors) do
      nil ->
        validation_error(validation_fields(error.errors))

      conflict_error ->
        conflict_error(conflict_error)
    end
  end

  def format(%Ash.Error.Forbidden{} = error, _stacktrace) do
    %{type: "forbidden", message: forbidden_message(error)}
  end

  def format(error, stacktrace) do
    require Logger

    stacktrace =
      stacktrace ||
        case Process.info(self(), :current_stacktrace) do
          {:current_stacktrace, trace} -> trace
          _ -> []
        end

    formatted_error = Exception.format(:error, error, stacktrace)
    Logger.error("Alva.Error: Unhandled error:\n#{formatted_error}")

    expose? =
      case Application.fetch_env(:alva, :expose_unknown_errors) do
        {:ok, val} ->
          val

        :error ->
          Code.ensure_loaded?(Mix) && function_exported?(Mix, :env, 0) &&
            Mix.env() in [:dev, :test]
      end

    if expose? do
      %{
        type: "unknown",
        message: Exception.message(error),
        details: formatted_error
      }
    else
      %{
        type: "unknown",
        message: "An unexpected error occurred"
      }
    end
  end

  defp find_conflict(errors) do
    Enum.find(errors, fn sub_error ->
      # It's a conflict if it doesn't have a field (global error)
      is_nil(Map.get(sub_error, :field))
    end)
  end

  defp not_found do
    %{
      type: "not_found",
      message: "Resource not found"
    }
  end

  defp validation_error(fields) do
    %{
      type: "validation",
      message: "Validation failed",
      fields: fields
    }
  end

  defp validation_fields(errors) do
    errors
    |> Enum.reject(&is_nil(&1.field))
    |> Enum.reduce(%{}, fn %{field: field} = sub_error, acc ->
      field_key = validation_field_key(sub_error, field)
      message = validation_message(sub_error, field)
      Map.update(acc, field_key, [message], &[message | &1])
    end)
  end

  defp validation_message(sub_error, field) do
    message =
      sub_error
      |> clean_validation_error()
      |> Exception.message()
      |> String.trim()

    Regex.replace(~r/^(attribute|argument)\s+#{field}\s+/i, message, "")
  end

  defp clean_validation_error(%{bread_crumbs: _} = sub_error), do: %{sub_error | bread_crumbs: []}
  defp clean_validation_error(sub_error), do: sub_error

  defp validation_field_key(sub_error, field) do
    case Map.get(sub_error, :path) || [] do
      [] ->
        to_string(field)

      path ->
        path
        |> maybe_append_field(field)
        |> Enum.map_join(".", &to_string/1)
    end
  end

  defp maybe_append_field(path, field) do
    case Enum.reverse(path) do
      [^field | _] = reversed -> Enum.reverse(reversed)
      reversed -> Enum.reverse([field | reversed])
    end
  end

  defp conflict_error(conflict_error) do
    %{
      type: "conflict",
      code: Map.get(conflict_error, :code) || "conflict",
      message: Exception.message(conflict_error)
    }
  end

  defp forbidden_message(error) do
    String.trim(Exception.message(error))
  end
end
