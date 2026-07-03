defmodule Alva.Error do
  @moduledoc """
  Normalizes Ash errors into a standard format for LiveVue.
  """

  def format(%Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}) do
    %{
      type: "not_found",
      message: "Resource not found"
    }
  end

  def format(%Ash.Error.Query.NotFound{}) do
    %{
      type: "not_found",
      message: "Resource not found"
    }
  end

  def format(%Ash.Error.Invalid{} = error) do
    case find_conflict(error.errors) do
      nil ->
        fields =
          error.errors
          |> Enum.reduce(%{}, fn
            %{field: field} = sub_error, acc when not is_nil(field) ->
              clean_error =
                if Map.has_key?(sub_error, :bread_crumbs),
                  do: %{sub_error | bread_crumbs: []},
                  else: sub_error

              msg = String.trim(Exception.message(clean_error))

              # clean up "attribute " prefix that Ash sometimes inserts
              msg = Regex.replace(~r/^(attribute|argument)\s+#{field}\s+/i, msg, "")

              path = Map.get(sub_error, :path) || []
              
              field_key = 
                case path do
                  [] -> to_string(field)
                  p -> 
                    if List.last(p) == field do
                      Enum.map_join(p, ".", &to_string/1)
                    else
                      Enum.map_join(p ++ [field], ".", &to_string/1)
                    end
                end

              Map.update(acc, field_key, [msg], &[msg | &1])

            _, acc ->
              acc
          end)

        %{
          type: "validation",
          message: "Validation failed",
          fields: fields
        }

      conflict_error ->
        code =
          case Map.get(conflict_error, :code) do
            nil -> "conflict"
            val -> val
          end

        message = Exception.message(conflict_error)

        %{
          type: "conflict",
          code: code,
          message: message
        }
    end
  end

  def format(%Ash.Error.Forbidden{} = error) do
    message =
      case String.trim(Exception.message(error)) do
        "" -> "Forbidden"
        msg -> msg
      end

    %{
      type: "forbidden",
      message: message
    }
  end

  def format(error) do
    require Logger
    
    formatted_error = Exception.format(:error, error, [])
    Logger.error("Alva.Error: Unhandled error:\n#{formatted_error}")

    expose? = 
      case Application.fetch_env(:alva, :expose_unknown_errors) do
        {:ok, val} -> val
        :error -> Code.ensure_loaded?(Mix) && function_exported?(Mix, :env, 0) && Mix.env() in [:dev, :test]
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
end
