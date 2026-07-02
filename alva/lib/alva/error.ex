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

  def format(error) do
    %{
      type: "unknown",
      message: Exception.message(error)
    }
  end
end
