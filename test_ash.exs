defmodule TestResource do
  use Ash.Resource, domain: nil

  attributes do
    uuid_primary_key :id
    attribute :name, :string
    attribute :age, :integer
  end

  actions do
    create :create_all do
      accept :*
    end

    create :create_list do
      accept [:name]
    end
  end
end

action = Ash.Resource.Info.action(TestResource, :create_all)
IO.inspect(action.accept, label: "create_all accept")

action2 = Ash.Resource.Info.action(TestResource, :create_list)
IO.inspect(action2.accept, label: "create_list accept")
