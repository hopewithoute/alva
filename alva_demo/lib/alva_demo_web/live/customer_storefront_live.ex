defmodule AlvaDemoWeb.CustomerStorefrontLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    domains: [AlvaDemo.Sales, AlvaDemo.Catalog, AlvaDemo.Support],
    collections: [
      {:sales_orders,
       source_input: :sales_order_collection_source_input,
       subscriptions: ["order:created", "order:updated"]},
      {:products,
       source_input: :product_collection_source_input, subscriptions: ["product:updated"]}
    ],
    streams: [:support_messages],
    subscriptions: ["support_message:created"]

  def render(assigns) do
    ~H"""
    <.vue
      id="customer-storefront-page"
      v-component="CustomerStorefrontPage"
      v-inject="layout"
      v-socket={@socket}
      sales_orders={@streams.sales_orders}
      products={@streams.products}
      support_messages={@support_messages}
    />
    """
  end

  def sales_order_collection_source_input, do: %{"sort" => "-created_at"}
  def product_collection_source_input, do: %{"sort" => "name"}
end
