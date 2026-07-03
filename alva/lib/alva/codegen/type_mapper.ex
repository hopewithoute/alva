defmodule Alva.Codegen.TypeMapper do
  @moduledoc """
  Maps Ash types to TypeScript types.
  """

  def map_type({:array, type}) do
    "#{map_type(type)}[]"
  end

  def map_type(type) when type in [Ash.Type.String, :string, Ash.Type.CiString, :ci_string, Ash.Type.UUID, :uuid, Ash.Type.UtcDatetime, :utc_datetime, Ash.Type.UtcDatetimeUsec, :utc_datetime_usec, Ash.Type.Date, :date], do: "string"

  def map_type(type) when type in [Ash.Type.Integer, :integer, Ash.Type.Float, :float, Ash.Type.Decimal, :decimal], do: "number"

  def map_type(type) when type in [Ash.Type.Boolean, :boolean], do: "boolean"

  def map_type(type) when type in [Ash.Type.Map, :map], do: "Record<string, any>"

  def map_type(type) when type in [Ash.Type.File, :file], do: "File"

  # Fallback
  def map_type(_other), do: "any"
end
