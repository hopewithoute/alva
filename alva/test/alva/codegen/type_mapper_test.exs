defmodule Alva.Codegen.TypeMapperTest do
  use ExUnit.Case
  alias Alva.Codegen.TypeMapper

  test "maps primitive types" do
    assert TypeMapper.map_type(:string) == "string"
    assert TypeMapper.map_type(Ash.Type.String) == "string"
    assert TypeMapper.map_type(:integer) == "number"
    assert TypeMapper.map_type(Ash.Type.Integer) == "number"
    assert TypeMapper.map_type(:boolean) == "boolean"
    assert TypeMapper.map_type(:utc_datetime) == "string"
    assert TypeMapper.map_type(:date) == "string"
    assert TypeMapper.map_type(:uuid) == "string"
    assert TypeMapper.map_type(:float) == "number"
    assert TypeMapper.map_type(:decimal) == "number"
    assert TypeMapper.map_type(:map) == "Record<string, any>"
    assert TypeMapper.map_type(Ash.Type.Map) == "Record<string, any>"
  end

  test "maps array types" do
    assert TypeMapper.map_type({:array, :string}) == "string[]"
    assert TypeMapper.map_type({:array, :integer}) == "number[]"
  end

  test "maps fallback to any" do
    assert TypeMapper.map_type(:unknown_type) == "any"
  end

  defmodule StatusEnum do
    use Ash.Type.Enum, values: [:active, :archived, :pending]
  end

  defmodule ProfileEmbed do
    use Ash.Resource, data_layer: :embedded

    attributes do
      attribute(:bio, :string)
      attribute(:age, :integer, allow_nil?: false)
    end
  end

  test "maps enums" do
    assert TypeMapper.map_type(StatusEnum) == "\"active\" | \"archived\" | \"pending\""
  end

  test "maps embedded resources" do
    result = TypeMapper.map_type(ProfileEmbed)
    assert result =~ "bio?: string"
    assert result =~ "age: number"
    assert result =~ "{ "
    assert result =~ " }"
  end

  test "maps unions" do
    constraints = [
      types: [
        string_val: [type: :string],
        int_val: [type: :integer]
      ]
    ]

    assert TypeMapper.map_type(Ash.Type.Union, constraints) == "string | number"
  end
end
