defmodule AlvaDemo.Catalog.Product do
  use Ash.Resource,
    domain: AlvaDemo.Catalog,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Alva.Resource]

  live_vue do
    event "catalog.list_products", action: :read
  end

  actions do
    defaults [:destroy]
    
    read :read do
      primary? true
      # Must be public to expose via Alva
      public? true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      allow_nil? false
      public? true
    end

    attribute :price, :integer do
      allow_nil? false
      public? true
    end

    attribute :stock, :integer do
      allow_nil? false
      public? true
    end

    attribute :media_reference, :string do
      allow_nil? false
      public? true
    end
  end
end
