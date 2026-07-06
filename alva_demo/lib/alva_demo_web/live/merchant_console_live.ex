defmodule AlvaDemoWeb.MerchantConsoleLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    domains: [AlvaDemo.Sales, AlvaDemo.Catalog, AlvaDemo.Support],
    collections: [
      {:sales_orders,
       source_input: :sales_order_collection_source_input,
       subscriptions: ["order:created", "order:updated"]},
      {:products,
       source_input: :product_collection_source_input, subscriptions: ["product:updated"]},
      {:conversations,
       source_input: :conversation_collection_source_input,
       subscriptions: ["conversation:created", "conversation:updated"]}
    ],
    streams: [:support_messages],
    subscriptions: ["support_message:created"]

  def render(assigns) do
    ~H"""
    <.vue
      id="merchant-console-page"
      v-component="MerchantConsolePage"
      v-inject="layout"
      v-socket={@socket}
      sales_orders={@streams.sales_orders}
      products={@streams.products}
      conversations={@streams.conversations}
      support_messages={@support_messages}
    />
    """
  end

  def sales_order_collection_source_input, do: %{"sort" => "-created_at"}
  def product_collection_source_input, do: %{"sort" => "stock"}
  def conversation_collection_source_input, do: %{"sort" => "-last_message_at"}
end
