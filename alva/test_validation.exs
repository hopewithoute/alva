defmodule TestValidationResource do
  use Ash.Resource, data_layer: Ash.DataLayer.Ets
  ets do
    private?(true)
  end
  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
  end
  identities do
    identity :unique_name, [:name]
  end
  actions do
    create :create do
      accept [:name]
    end
  end
end
changeset = Ash.Changeset.for_create(TestValidationResource, :create, %{name: "Test"})
IO.inspect(changeset.valid?, label: "Valid?")
# Let's insert it
Ash.create!(changeset)
# Now create another changeset with same name
changeset2 = Ash.Changeset.for_create(TestValidationResource, :create, %{name: "Test"})
IO.inspect(changeset2.valid?, label: "Valid 2?")
