defmodule Alva.DispatcherTest do
  use ExUnit.Case

  defmodule TestResource do
    use Ash.Resource,
      domain: Alva.DispatcherTest.TestDomain,
      validate_domain_inclusion?: false,
      data_layer: Ash.DataLayer.Ets,
      extensions: [Alva.Resource]

    ets do
      private?(true)
    end

    resource do
      require_primary_key?(false)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    actions do
      read :read do
        primary? true
        pagination offset?: true, required?: false
      end

      create :create do
        accept([:name])
      end

      destroy :archive do
        accept([])
      end

      action :say_hello, :string do
        argument(:name, :string, allow_nil?: false)

        run(fn input, _context ->
          {:ok, "Hello #{input.arguments.name}"}
        end)
      end

      read :search do
        argument(:query, :string, allow_nil?: false)
        filter(expr(name == ^arg(:query)))
      end
    end

    live_vue do
      event("test.archive", action: :archive, lookup: :id)
      event("test.say_hello", action: :say_hello)
      event("test.get", action: :read, lookup: :id)
      event("test.list", action: :read)
      event("test.search", action: :search)
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [Alva.Domain]

    resources do
      resource(Alva.DispatcherTest.TestResource)
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
    result =
      Alva.Dispatcher.dispatch("test.say_hello", %{"name" => "World"}, domains: [TestDomain])

    assert result.ok == true
    assert result.data == "Hello World"
  end

  test "dispatch returns error for :action event with invalid args" do
    result = Alva.Dispatcher.dispatch("test.say_hello", %{}, domains: [TestDomain])

    assert result.ok == false
    assert result.error.type == "validation"
  end

  test "dispatch handles :read event with lookup as Get action", %{record: record} do
    result = Alva.Dispatcher.dispatch("test.get", %{"id" => record.id}, domains: [TestDomain])

    assert result.ok == true
    assert is_map(result.data)
    assert result.data.id == record.id
  end

  test "dispatch returns not_found for :read Get action with missing id" do
    result = Alva.Dispatcher.dispatch("test.get", %{}, domains: [TestDomain])

    assert result.ok == false
    assert result.error.type == "not_found"
  end

  test "dispatch handles :read event without lookup as List action", %{record: record} do
    result = Alva.Dispatcher.dispatch("test.list", %{}, domains: [TestDomain])

    assert result.ok == true
    assert is_list(result.data)
    assert Enum.any?(result.data, fn r -> r.id == record.id end)
  end

  test "dispatch handles :read event with arguments for filtering" do
    # create another record so we can filter
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Other"}))

    result = Alva.Dispatcher.dispatch("test.search", %{"query" => "Other"}, domains: [TestDomain])

    assert result.ok == true
    assert is_list(result.data)
    assert length(result.data) == 1
    assert hd(result.data).name == "Other"
  end

  test "dispatch handles :read event list by stripping meta from params" do
    result = Alva.Dispatcher.dispatch("test.list", %{"meta" => %{"other" => 1}}, domains: [TestDomain])

    assert result.ok == true
    assert is_list(result.data)
  end

  test "dispatch handles :read event list with pagination" do
    # create multiple records
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Page1"}))
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Page2"}))
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Page3"}))

    result = Alva.Dispatcher.dispatch("test.list", %{"page" => %{"limit" => 2, "offset" => 0, "hacked" => "yes"}}, domains: [TestDomain])

    assert result.ok == true
    assert is_list(result.data)
    assert length(result.data) == 2
    assert result.meta.pagination.limit == 2
    assert result.meta.pagination.offset == 0
    assert result.meta.pagination.has_more == true
  end

  test "dispatch handles :read event list with non-map pagination" do
    result = Alva.Dispatcher.dispatch("test.list", %{"page" => "invalid"}, domains: [TestDomain])
    assert result.ok == true
    assert is_list(result.data)
  end

  test "dispatch handles :read event list with sort" do
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Zebra"}))
    Ash.create!(Ash.Changeset.for_create(TestResource, :create, %{name: "Apple"}))

    result = Alva.Dispatcher.dispatch("test.list", %{"sort" => "name"}, domains: [TestDomain])

    assert result.ok == true
    assert is_list(result.data)
    
    names = Enum.map(result.data, & &1.name)
    assert names == ["Apple", "Test", "Zebra"]
    
    result_desc = Alva.Dispatcher.dispatch("test.list", %{"sort" => "-name"}, domains: [TestDomain])
    names_desc = Enum.map(result_desc.data, & &1.name)
    assert names_desc == ["Zebra", "Test", "Apple"]
  end

  test "dispatch handles :read event lookup by stripping meta from params", %{record: record} do
    result = Alva.Dispatcher.dispatch("test.get", %{"id" => record.id, "meta" => %{"page" => 1}}, domains: [TestDomain])

    assert result.ok == true
    assert result.data.id == record.id
  end
end
