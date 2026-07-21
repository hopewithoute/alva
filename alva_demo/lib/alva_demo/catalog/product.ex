defmodule AlvaDemo.Catalog.Product do
  require Ash.Query

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

  alva do
    event(:catalog_get_product, name: "catalog.get_product", action: :read, lookup: :id)

    event(:catalog_list_products,
      name: "catalog.list_products",
      action: :list,
      enable_filter: true
    )

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
      argument(:min_stock, :integer, allow_nil?: true)
      argument(:max_stock, :integer, allow_nil?: true)

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(name: :asc)
        |> filter_product_query(Ash.Query.get_argument(query, :query))
        |> filter_min_stock(Ash.Query.get_argument(query, :min_stock))
        |> filter_max_stock(Ash.Query.get_argument(query, :max_stock))
      end)
    end

    update :adjust_stock do
      public?(true)
      accept([:stock])
      validate(compare(:stock, greater_than_or_equal_to: 0), message: "Stock cannot be negative")
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

  defp filter_min_stock(query, nil), do: query

  defp filter_min_stock(query, min_stock) when is_integer(min_stock) do
    require Ash.Expr
    Ash.Query.filter(query, Ash.Expr.expr(stock >= ^min_stock))
  end

  defp filter_min_stock(query, min_stock) when is_binary(min_stock) do
    case Integer.parse(min_stock) do
      {val, _} -> filter_min_stock(query, val)
      :error -> query
    end
  end

  defp filter_min_stock(query, _), do: query

  defp filter_max_stock(query, nil), do: query

  defp filter_max_stock(query, max_stock) when is_integer(max_stock) do
    require Ash.Expr
    Ash.Query.filter(query, Ash.Expr.expr(stock <= ^max_stock))
  end

  defp filter_max_stock(query, max_stock) when is_binary(max_stock) do
    case Integer.parse(max_stock) do
      {val, _} -> filter_max_stock(query, val)
      :error -> query
    end
  end

  defp filter_max_stock(query, _), do: query

  defp search_pattern(nil), do: nil

  defp search_pattern(search_term) when is_binary(search_term) do
    case String.trim(search_term) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
