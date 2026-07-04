defmodule AlvaDemo.Catalog.Product do
  use Ash.Resource,
    domain: AlvaDemo.Catalog,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub],
    extensions: [Alva.Resource]

  pub_sub do
    module(AlvaDemoWeb.Endpoint)
    prefix("product")
    publish(:adjust_stock, ["updated"])
    publish(:upload_media, ["updated"])
  end

  live_vue do
    event("catalog.list_products", action: :read)
    event("catalog.adjust_stock", action: :adjust_stock)
    event("catalog.upload_media", action: :upload_media)

    collection :products do
      source(event: "catalog.list_products", mode: :reset)
      update(on: "adjust_stock")
      update(on: "upload_media")
    end
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
      public?(true)
    end

    update :adjust_stock do
      public?(true)
      accept([:stock])
    end

    update :upload_media do
      public?(true)
      accept([])
      require_atomic?(false)
      argument(:media, Ash.Type.File, allow_nil?: false)

      change({AlvaDemo.Catalog.Changes.StoreMedia, arg: :media, attribute: :media_reference})
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :description, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :price, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :stock, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :media_reference, :string do
      allow_nil?(false)
      public?(true)
    end
  end
end
