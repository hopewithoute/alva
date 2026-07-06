defmodule AlvaDemoWeb.MerchantConsoleLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    domains: [AlvaDemo.Sales, AlvaDemo.Catalog, AlvaDemo.Support],
    collections: [
      sales_orders: [source_input: :sales_order_collection_source_input],
      products: [source_input: :product_collection_source_input],
      conversations: [source_input: :conversation_collection_source_input]
    ]

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:support_messages, [])
      |> Alva.LiveView.activate_stream(:support_messages)
      |> maybe_subscribe_support_messages()

    {:ok, socket}
  end

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

  defp maybe_subscribe_support_messages(socket) do
    if Phoenix.LiveView.connected?(socket) do
      :ok = AlvaDemoWeb.Endpoint.subscribe("support_message:created")
      socket
    else
      socket
    end
  end
end
