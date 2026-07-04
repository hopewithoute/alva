defmodule AlvaDemo.Sales.Order do
  use Ash.Resource,
    domain: AlvaDemo.Sales,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Alva.Resource]

  live_vue do
    event "sales.create_order", action: :create
    event "sales.list_orders", action: :read
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
      public? true
    end

    create :create do
      primary? true
      public? true
      accept [:customer_name, :product_id, :quantity]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :customer_name, :string do
      allow_nil? false
      public? true
    end

    attribute :quantity, :integer do
      allow_nil? false
      default 1
      public? true
    end

    attribute :lifecycle_status, :atom do
      constraints [one_of: [:new, :processing, :fulfilled, :cancelled]]
      default :new
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :product, AlvaDemo.Catalog.Product do
      allow_nil? false
      public? true
    end
  end
end
