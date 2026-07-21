defmodule Alva.Codegen.TypeMapper do
  @moduledoc since: "0.1.0"
  @moduledoc """
  Maps Ash type specifications to TypeScript type annotations.

  ## Type Mapping

    * `:string`, `:uuid`, `:ci_string`, date/time types → `string`
    * `:integer`, `:float`, `:decimal` → `number`
    * `:boolean` → `boolean`
    * `:map` → `Record<string, any>`
    * `:file` → `File` (or `string[]` for arrays of files)
    * `{:array, inner}` → `InnerType[]`
    * Embedded resources → inline object type
    * Enums → union of string literals
    * Union types (`one_of`) → union of mapped types
    * Unknown types → `any`

  See `Alva.Codegen.InputContract` and `Alva.Codegen.DtoGenerator` for consumers.
  """

  @doc """
  Maps a single Ash type to its TypeScript equivalent.
  """
  @doc since: "0.1.0"
  def map_type(type, constraints \\ [])

  def map_type({:array, type}, constraints) do
    items_constraints = Keyword.get(constraints || [], :items, [])
    "#{map_type(type, items_constraints)}[]"
  end

  def map_type(type, _constraints)
      when type in [
             Ash.Type.String,
             :string,
             Ash.Type.CiString,
             :ci_string,
             Ash.Type.UUID,
             :uuid,
             Ash.Type.UtcDatetime,
             :utc_datetime,
             Ash.Type.UtcDatetimeUsec,
             :utc_datetime_usec,
             Ash.Type.Date,
             :date
           ],
      do: "string"

  def map_type(type, _constraints)
      when type in [
             Ash.Type.Integer,
             :integer,
             Ash.Type.Float,
             :float,
             Ash.Type.Decimal,
             :decimal
           ],
      do: "number"

  def map_type(type, _constraints) when type in [Ash.Type.Boolean, :boolean], do: "boolean"

  def map_type(type, _constraints) when type in [Ash.Type.Map, :map], do: "Record<string, any>"

  def map_type(type, _constraints) when type in [Ash.Type.File, :file], do: "File"

  def map_type(type, constraints) when is_atom(type) do
    cond do
      embedded_resource?(type) ->
        map_embedded_resource(type, constraints)

      enum_type?(type) ->
        type.values() |> Enum.map_join(" | ", fn v -> "\"#{v}\"" end)

      Keyword.has_key?(constraints || [], :types) ->
        types = Keyword.get(constraints, :types, [])

        types
        |> Enum.map(fn {_key, config} ->
          subtype = Keyword.get(config, :type)
          subconstraints = Keyword.get(config, :constraints, [])
          map_type(subtype, subconstraints)
        end)
        |> Enum.uniq()
        |> Enum.join(" | ")

      Keyword.has_key?(constraints || [], :one_of) ->
        Keyword.get(constraints, :one_of)
        |> Enum.map_join(" | ", fn v -> "\"#{v}\"" end)

      true ->
        "any"
    end
  end

  # Fallback
  def map_type(_other, _constraints), do: "any"

  # Reflection Helpers
  defp embedded_resource?(type) do
    Code.ensure_loaded?(type) and function_exported?(Ash.Resource.Info, :resource?, 1) and
      Ash.Resource.Info.resource?(type)
  end

  defp enum_type?(type) do
    Code.ensure_loaded?(type) and Spark.implements_behaviour?(type, Ash.Type.Enum)
  end

  defp map_embedded_resource(type, _constraints) do
    attrs = Ash.Resource.Info.attributes(type)

    # Embedded resources typically do not have field policies, but we fetch them if present
    policy_fields =
      if Code.ensure_loaded?(Ash.Policy.Info) and
           function_exported?(Ash.Policy.Info, :field_policies, 1) do
        (Ash.Policy.Info.field_policies(type) || [])
        |> Enum.flat_map(& &1.fields)
        |> Enum.uniq()
      else
        []
      end

    fields =
      Enum.map(attrs, fn attr ->
        ts_type = map_type(attr.type, attr.constraints)
        optional? = attr.name in policy_fields or Map.get(attr, :allow_nil?, true)

        if optional? do
          "#{attr.name}?: #{ts_type}"
        else
          "#{attr.name}: #{ts_type}"
        end
      end)

    if fields == [] do
      "{ }"
    else
      "{ " <> Enum.join(fields, "; ") <> "; }"
    end
  end
end
