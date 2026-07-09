defmodule Alva.Serializer do
  @moduledoc """
  Translates Ash records into JSON-friendly payloads, extracting explicitly exposed metadata
  and stripping internal fields.

  ### Type Coercion
  During serialization, some Erlang/Elixir specific types are safely coerced for JSON:
  * **Tuples** are converted to lists (e.g., `{:ok, val}` becomes `["ok", val]`).
  * **Atoms** (other than `true`, `false`, and `nil`) are converted to strings.
  """

  @doc """
  Serializes a record or list of records. 

  Options:
  - `:expose_metadata` (list of atoms) - Keys to extract from `__metadata__` and return alongside the payload.
  """
  def serialize(record, opts \\ [])

  def serialize(record, opts)
      when is_map(record) and not is_struct(record, Ash.Notifier.Notification) do
    expose_keys = Keyword.get(opts, :expose_metadata, [])
    exposed_meta = extract_exposed_metadata(record, expose_keys)
    {strip_metadata(record), exposed_meta}
  end

  def serialize(list, opts) when is_list(list) do
    expose_keys = Keyword.get(opts, :expose_metadata, [])

    exposed_meta =
      case list do
        [first | _] -> extract_exposed_metadata(first, expose_keys)
        [] -> %{}
      end

    {strip_metadata(list), exposed_meta}
  end

  def serialize(result, _opts) do
    {strip_metadata(result), %{}}
  end

  defp extract_exposed_metadata(_record, []), do: %{}

  defp extract_exposed_metadata(%{__metadata__: metadata}, keys) when is_map(metadata) do
    metadata
    |> Map.take(keys)
    |> Enum.into(%{})
  end

  defp extract_exposed_metadata(_, _), do: %{}

  def strip_metadata(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  def strip_metadata(%NaiveDateTime{} = datetime), do: NaiveDateTime.to_iso8601(datetime)
  def strip_metadata(%Date{} = date), do: Date.to_iso8601(date)
  def strip_metadata(%Time{} = time), do: Time.to_iso8601(time)

  def strip_metadata(%module{} = record) do
    if Ash.Resource.Info.resource?(module) do
      strip_metadata_with_fields(record, public_fields(module))
    else
      record
      |> Map.from_struct()
      |> drop_metadata()
      |> Map.new(fn {k, v} -> {k, strip_metadata(v)} end)
    end
  end

  def strip_metadata([first | _] = list) when is_map(first) do
    case Map.get(first, :__struct__) do
      module when not is_nil(module) ->
        if Ash.Resource.Info.resource?(module) do
          fields = public_fields(module)
          Enum.map(list, &strip_metadata_with_fields(&1, fields))
        else
          Enum.map(list, &strip_metadata/1)
        end

      _ ->
        Enum.map(list, &strip_metadata/1)
    end
  end

  def strip_metadata(list) when is_list(list) do
    Enum.map(list, &strip_metadata/1)
  end

  def strip_metadata(%{} = map) when not is_struct(map) do
    map
    |> drop_metadata()
    |> Map.new(fn {k, v} -> {k, strip_metadata(v)} end)
  end

  def strip_metadata(atom) when is_atom(atom) and atom not in [nil, true, false] do
    Atom.to_string(atom)
  end

  def strip_metadata(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> strip_metadata()
  end

  def strip_metadata(other), do: other

  defp strip_metadata_with_fields(record, fields) do
    fields
    |> Map.new(fn field ->
      case Map.get(record, field) do
        %{__struct__: Ash.NotLoaded} -> {field, :skip}
        %{__struct__: Ash.ForbiddenField} -> {field, :skip}
        val -> {field, strip_metadata(val)}
      end
    end)
    |> Map.reject(fn {_k, v} -> v == :skip end)
  end

  defp drop_metadata(map) do
    Map.drop(map, [:__meta__, :__metadata__])
  end

  defp public_fields(resource) do
    Alva.Registry.public_fields(resource)
  end
end
