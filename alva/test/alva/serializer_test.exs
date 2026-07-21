defmodule Alva.SerializerTest do
  use ExUnit.Case, async: true

  alias Alva.Serializer

  defmodule TestStruct do
    defstruct [:a, :b, :__meta__, :__metadata__]
  end

  defmodule MockResource do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
      attribute :secret, :string, public?: false
    end
  end

  setup do
    :ok
  end

  test "serialize single map without metadata" do
    assert Serializer.serialize(%{a: 1}) == {%{a: 1}, %{}}
  end

  test "serialize single map with expose_metadata" do
    map = %{a: 1, __metadata__: %{cursor: "123", other: "456"}}
    assert Serializer.serialize(map, expose_metadata: [:cursor]) == {%{a: 1}, %{cursor: "123"}}

    invalid_meta = %{a: 1, __metadata__: "not a map"}
    assert Serializer.serialize(invalid_meta, expose_metadata: [:cursor]) == {%{a: 1}, %{}}
  end

  test "serialize list of maps with expose_metadata" do
    list = [
      %{a: 1, __metadata__: %{cursor: "123"}},
      %{a: 2}
    ]

    assert Serializer.serialize(list, expose_metadata: [:cursor]) ==
             {[%{a: 1}, %{a: 2}], %{cursor: "123"}}

    assert Serializer.serialize([], expose_metadata: [:cursor]) == {[], %{}}
  end

  test "serialize fallback (Ash Notification)" do
    notification = %Ash.Notifier.Notification{resource: Foo, action: %{name: :bar}}
    {res, _} = Serializer.serialize(notification, [])
    assert res.resource == "Elixir.Foo"
    assert res.action.name == "bar"
  end

  test "strip_metadata with Ash Resource" do
    record = %MockResource{id: "1", name: %Ash.NotLoaded{}, secret: %Ash.ForbiddenField{}}
    assert Serializer.strip_metadata(record) == %{id: "1"}

    list = [%MockResource{id: "1", name: "Test"}, %MockResource{id: "2", name: %Ash.NotLoaded{}}]

    assert Serializer.strip_metadata(list) == [
             %{id: "1", name: "Test"},
             %{id: "2"}
           ]
  end

  test "strip_metadata datetime formats" do
    dt = ~U[2021-01-01 12:00:00Z]
    assert Serializer.strip_metadata(dt) == "2021-01-01T12:00:00Z"

    ndt = ~N[2021-01-01 12:00:00]
    assert Serializer.strip_metadata(ndt) == "2021-01-01T12:00:00"

    d = ~D[2021-01-01]
    assert Serializer.strip_metadata(d) == "2021-01-01"

    t = ~T[12:00:00]
    assert Serializer.strip_metadata(t) == "12:00:00"
  end

  test "strip_metadata non-resource struct" do
    s = %TestStruct{a: 1, b: 2, __meta__: "meta", __metadata__: "metadata"}
    assert Serializer.strip_metadata(s) == %{a: 1, b: 2}

    list = [%TestStruct{a: 1}, %TestStruct{a: 2}]
    assert Serializer.strip_metadata(list) == [%{a: 1, b: nil}, %{a: 2, b: nil}]
  end

  test "strip_metadata map" do
    map = %{a: 1, __meta__: "meta", __metadata__: "metadata"}
    assert Serializer.strip_metadata(map) == %{a: 1}

    list = [%{a: 1}, %{a: 2}]
    assert Serializer.strip_metadata(list) == [%{a: 1}, %{a: 2}]
  end

  test "strip_metadata atom" do
    assert Serializer.strip_metadata(:atom) == "atom"
    assert Serializer.strip_metadata(nil) == nil
    assert Serializer.strip_metadata(true) == true
    assert Serializer.strip_metadata(false) == false
  end

  test "strip_metadata tuple" do
    assert Serializer.strip_metadata({:a, 1, %{__meta__: "x", b: 2}}) == ["a", 1, %{b: 2}]
  end

  test "strip_metadata others" do
    assert Serializer.strip_metadata("string") == "string"
    assert Serializer.strip_metadata(123) == 123
  end
end
