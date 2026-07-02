defmodule Alva.DispatcherTest do
  use ExUnit.Case

  defmodule TestResource do
    use Ash.Resource,
      domain: Alva.DispatcherTest.TestDomain,
      validate_domain_inclusion?: false,
      data_layer: Ash.DataLayer.Ets,
      extensions: [Alva.Resource]

    ets do
      private? true
    end

    resource do
      require_primary_key? false
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]

      create :create do
        accept [:name]
      end

      destroy :archive do
        accept []
      end

      action :say_hello, :string do
        argument :name, :string, allow_nil?: false
        run fn input, _context ->
          {:ok, "Hello #{input.arguments.name}"}
        end
      end
    end

    live_vue do
      event "test.archive", action: :archive, lookup: :id
      event "test.say_hello", action: :say_hello
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

    resources do
      resource Alva.DispatcherTest.TestResource
    end
  end

  setup do
    record = Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Test"}))
    %{record: record}
  end

  test "dispatch handles :destroy event", %{record: record} do
    # Dispatch destroy
    result = Alva.Dispatcher.dispatch("test.archive", %{"id" => record.id}, domains: [TestDomain])

    assert result.ok == true
    assert result.data.id == record.id
    
    # Assert record is deleted
    assert_raise Ash.Error.Invalid, fn ->
      Ash.get!(TestResource, record.id)
    end
  end

  test "dispatch returns error for :destroy event with nil id" do
    result = Alva.Dispatcher.dispatch("test.archive", %{}, domains: [TestDomain])

    assert result.ok == false
    assert result.error.type == "not_found"
  end

  test "dispatch handles :action event" do
    result = Alva.Dispatcher.dispatch("test.say_hello", %{"name" => "World"}, domains: [TestDomain])

    assert result.ok == true
    assert result.data == "Hello World"
  end

  test "dispatch returns error for :action event with invalid args" do
    result = Alva.Dispatcher.dispatch("test.say_hello", %{}, domains: [TestDomain])

    assert result.ok == false
    assert result.error.type == "validation"
  end
end
