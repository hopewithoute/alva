defmodule AlvaDemo.Sales.Order do
  use Ash.Resource,
    domain: AlvaDemo.Sales,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Alva.Resource]

  live_vue do
    event "sales.create_order", action: :create
    event "sales.list_orders", action: :read
    event "sales.begin_processing", action: :begin_processing
    event "sales.fulfill", action: :fulfill
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

    update :begin_processing do
      public? true
      require_atomic? false
      validate fn changeset, _context ->
        if changeset.data.lifecycle_status == :new do
          :ok
        else
          {:error, Ash.Error.Changes.InvalidAttribute.exception(field: :lifecycle_status, message: "Order must be in new state to begin processing")}
        end
      end
      change set_attribute(:lifecycle_status, :processing)
    end

    update :fulfill do
      public? true
      require_atomic? false
      validate fn changeset, _context ->
        if changeset.data.lifecycle_status == :processing do
          :ok
        else
          {:error, Ash.Error.Changes.InvalidAttribute.exception(field: :lifecycle_status, message: "Order must be in processing state to be fulfilled")}
        end
      end
      change set_attribute(:lifecycle_status, :fulfilled)
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
      constraints [min: 1]
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
