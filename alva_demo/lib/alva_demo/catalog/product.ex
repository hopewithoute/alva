defmodule AlvaDemo.Catalog.Product do
  require Ash.Query
  alias AlvaDemo.Subscriptions, as: DemoSubscriptions
  alias AlvaDemoWeb.ParamHelpers

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
    event(:catalog_list_products, name: "catalog.list_products", action: :list)
    event(:catalog_adjust_stock, name: "catalog.adjust_stock", action: :adjust_stock)
    event(:catalog_upload_media, name: "catalog.upload_media", action: :upload_media)
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
      public?(true)
    end

    read :list do
      public?(true)
      argument(:query, :string, allow_nil?: true)
      argument(:max_stock, :integer, allow_nil?: true)

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(name: :asc)
        |> filter_product_query(Ash.Query.get_argument(query, :query))
        |> filter_max_stock(Ash.Query.get_argument(query, :max_stock))
      end)
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

  defp filter_product_query(query, search_term) do
    case search_pattern(search_term) do
      nil ->
        query

      pattern ->
        require Ash.Expr

        Ash.Query.filter(
          query,
          Ash.Expr.expr(contains(name, ^pattern) or contains(description, ^pattern))
        )
    end
  end

  defp filter_max_stock(query, nil), do: query

  defp filter_max_stock(query, max_stock) do
    require Ash.Expr

    Ash.Query.filter(query, Ash.Expr.expr(stock <= ^max_stock))
  end

  defp search_pattern(nil), do: nil

  defp search_pattern(search_term) when is_binary(search_term) do
    case String.trim(search_term) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
