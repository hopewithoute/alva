defmodule TestResource do
  use Ash.Resource, domain: nil

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    attribute :age, :integer, public?: true
  end

  actions do
    create :create_all do
      accept :*
    end
  end
end

action = Ash.Resource.Info.action(TestResource, :create_all)
IO.inspect(action, limit: :infinity)
