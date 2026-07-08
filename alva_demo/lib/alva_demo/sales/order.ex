defmodule AlvaDemo.Sales.Order do
  require Ash.Query
  alias AlvaDemo.Subscriptions, as: DemoSubscriptions
  alias AlvaDemoWeb.ParamHelpers

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
    event(:sales_create_order, name: "sales.create_order", action: :create)
    event(:sales_list_orders, name: "sales.list_orders", action: :list)
    event(:sales_begin_processing, name: "sales.begin_processing", action: :begin_processing)
    event(:sales_fulfill, name: "sales.fulfill", action: :fulfill)

    subscription :sales_orders do
      name("sales_orders")
      kind(:stream)
      source(event: :sales_list_orders)

      scope(%{
        status: :string,
        customer_query: :string,
        require_customer: :boolean,
        product_query: :string,
        sort: :string
      })

      insert(on: :create, at: 0)
      update(on: :begin_processing)
      update(on: :fulfill)
      resolve(:resolve_sales_orders_scope)
    end
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
      public?(true)
    end

    read :list do
      public?(true)

      argument(:status, :atom,
        allow_nil?: true,
        constraints: [one_of: [:new, :processing, :fulfilled]]
      )

      argument(:customer_query, :string, allow_nil?: true)
      argument(:require_customer, :boolean, allow_nil?: false, default: false)
      argument(:product_query, :string, allow_nil?: true)

      prepare(fn query, _context ->
        require_customer? = Ash.Query.get_argument(query, :require_customer)
        customer_query = Ash.Query.get_argument(query, :customer_query)

        query =
          if require_customer? and is_nil(customer_query) do
            Ash.Query.filter(query, false)
          else
            query
          end

        query
        |> Ash.Query.sort(created_at: :desc)
        |> Ash.Query.load(:product)
        |> filter_status(Ash.Query.get_argument(query, :status))
        |> filter_customer_query(customer_query)
        |> filter_product_query(Ash.Query.get_argument(query, :product_query))
      end)
    end

    create :create do
      primary?(true)
      public?(true)
      accept([:customer_name, :product_id, :quantity])
      change(load(:product))
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

    create_timestamp :created_at do
      public?(true)
    end
  end

  relationships do
    belongs_to :product, AlvaDemo.Catalog.Product do
      allow_nil?(false)
      public?(true)
    end
  end

  def resolve_sales_orders_scope(input, socket) do
    source_input =
      socket
      |> sales_order_stream_defaults()
      |> DemoSubscriptions.with_defaults(input)

    with {:ok, items} <-
           DemoSubscriptions.load_stream_items(socket, "sales.list_orders", source_input) do
      {:ok,
       %{
         topics: [
           DemoSubscriptions.notifier_topic(__MODULE__, "created"),
           DemoSubscriptions.notifier_topic(__MODULE__, "updated")
         ],
         items: items
       }}
    end
  end

  defp filter_status(query, nil), do: query

  defp filter_status(query, status) do
    require Ash.Expr

    Ash.Query.filter(query, Ash.Expr.expr(lifecycle_status == ^status))
  end

  defp filter_customer_query(query, search_term) do
    case search_pattern(search_term) do
      nil ->
        query

      pattern ->
        require Ash.Expr

        Ash.Query.filter(query, Ash.Expr.expr(contains(customer_name, ^pattern)))
    end
  end

  defp filter_product_query(query, search_term) do
    case search_pattern(search_term) do
      nil ->
        query

      pattern ->
        require Ash.Expr

        Ash.Query.filter(query, Ash.Expr.expr(contains(product.name, ^pattern)))
    end
  end

  defp search_pattern(nil), do: nil

  defp search_pattern(search_term) when is_binary(search_term) do
    case String.trim(search_term) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp sales_order_stream_defaults(%{view: AlvaDemoWeb.CustomerStorefrontLive} = socket) do
    params = ParamHelpers.route_params(socket)

    %{
      "customer_query" => ParamHelpers.normalize_optional_string(params["customer_name"]),
      "require_customer" => true,
      "sort" => "-created_at"
    }
  end

  defp sales_order_stream_defaults(%{view: AlvaDemoWeb.MerchantConsoleLive} = socket) do
    params = ParamHelpers.route_params(socket)

    %{
      "status" => normalize_order_status(params["order_status"]),
      "customer_query" => ParamHelpers.normalize_optional_string(params["order_customer"]),
      "product_query" => ParamHelpers.normalize_optional_string(params["order_product"]),
      "sort" => "-created_at"
    }
  end

  defp sales_order_stream_defaults(_socket), do: %{"sort" => "-created_at"}

  defp normalize_order_status(status) do
    status
    |> ParamHelpers.normalize_optional_string()
    |> case do
      nil -> nil
      "all" -> nil
      value -> value
    end
  end
end
