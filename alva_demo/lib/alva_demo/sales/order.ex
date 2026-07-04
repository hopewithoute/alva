defmodule AlvaDemo.Sales.Order do
  use Ash.Resource,
    domain: AlvaDemo.Sales,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub],
    extensions: [Alva.Resource]

  pub_sub do
    module(AlvaDemoWeb.Endpoint)
    prefix("order")
    publish(:create, ["created"])
    publish(:begin_processing, ["updated"])
    publish(:fulfill, ["updated"])
  end

  live_vue do
    event("sales.create_order", action: :create)
    event("sales.list_orders", action: :read)
    event("sales.begin_processing", action: :begin_processing)
    event("sales.fulfill", action: :fulfill)

    stream :sales_orders do
      insert(on: "create")
      update(on: "begin_processing")
      update(on: "fulfill")
    end
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
      public?(true)
    end

    create :create do
      primary?(true)
      public?(true)
      accept([:customer_name, :product_id, :quantity])
    end

    update :begin_processing do
      public?(true)
      require_atomic?(false)
      validate({AlvaDemo.Sales.Validations.TransitionFrom, state: :new})
      change(set_attribute(:lifecycle_status, :processing))
    end

    update :fulfill do
      public?(true)
      require_atomic?(false)
      validate({AlvaDemo.Sales.Validations.TransitionFrom, state: :processing})
      change(set_attribute(:lifecycle_status, :fulfilled))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :customer_name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :quantity, :integer do
      allow_nil?(false)
      default(1)
      public?(true)
      constraints(min: 1)
    end

    attribute :lifecycle_status, :atom do
      constraints(one_of: [:new, :processing, :fulfilled])
      default(:new)
      allow_nil?(false)
      public?(true)
    end
  end

  relationships do
    belongs_to :product, AlvaDemo.Catalog.Product do
      allow_nil?(false)
      public?(true)
    end
  end
end
