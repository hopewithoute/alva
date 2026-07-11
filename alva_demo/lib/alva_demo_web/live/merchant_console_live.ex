defmodule AlvaDemoWeb.MerchantConsoleLive do
  use AlvaDemoWeb, :live_view
  import AlvaDemoWeb.ParamHelpers

  use Alva.LiveView,
    streams: [
      sales_orders: [
        resource: AlvaDemo.Sales.Order,
        source: :list,
        scope: %{
          status: :order_status,
          customer_query: :order_customer_query,
          product_query: :order_product_query
        },
        sync_on: [:create, :begin_processing, :fulfill]
      ],
      products: [
        resource: AlvaDemo.Catalog.Product,
        source: :list,
        scope: %{
          query: :inv_query,
          max_stock: :inv_max_stock
        },
        sync_on: [:adjust_stock, :upload_media]
      ],
      conversations: [
        resource: AlvaDemo.Support.Conversation,
        source: :list,
        scope: %{
          customer_query: :conv_customer_query,
          needs_merchant_reply: :conv_needs_reply
        },
        sync_on: [:create, :assign_merchant, :close]
      ],
      support_messages: [
        resource: AlvaDemo.Support.SupportMessage,
        source: :read_for_conversation,
        scope: %{conversation_id: :active_conversation_id},
        sync_on: [:create]
      ]
    ],
    uploads: ["catalog.upload_media"]

  def handle_params(params, _uri, socket) do
    {:noreply, socket |> assign(console_route_assigns(params)) |> Alva.LiveView.reconfigure_streams(params)}
  end

  def render(assigns) do
    ~H"""
    <.vue
      id="merchant-console-page"
      v-component="MerchantConsolePage"
      v-inject="layout"
      v-socket={@socket}
      sales_orders={Map.get(@streams, :sales_orders)}
      products={Map.get(@streams, :products)}
      conversations={Map.get(@streams, :conversations)}
      media={@uploads.media}
      active_conversation_id={@active_conversation_id}
      support_messages={Map.get(@streams, :support_messages)}
      new_orders_count={@new_orders_count}
      processing_orders_count={@processing_orders_count}
      waiting_conversations_count={@waiting_conversations_count}
      merchant_attention_count={@merchant_attention_count}
      is_order_filtered={@is_order_filtered}
      is_inventory_filtered={@is_inventory_filtered}
      is_conversation_filtered={@is_conversation_filtered}
      low_stock_count={@low_stock_count}
      order_filters={@order_filters}
      inventory_filters={@inventory_filters}
      conversation_filters={@conversation_filters}
    />
    """
  end

  defp console_route_assigns(params) do
    require Ash.Query

    new_orders_count =
      AlvaDemo.Sales.Order
      |> Ash.Query.filter(lifecycle_status == :new)
      |> Ash.count!()

    processing_orders_count =
      AlvaDemo.Sales.Order
      |> Ash.Query.filter(lifecycle_status == :processing)
      |> Ash.count!()

    waiting_conversations_count =
      AlvaDemo.Support.Conversation
      |> Ash.Query.filter(needs_merchant_reply == true)
      |> Ash.count!()

    low_stock_count =
      AlvaDemo.Catalog.Product
      |> Ash.Query.filter(stock <= 25)
      |> Ash.count!()

    %{
      active_conversation_id: normalize_conversation_id(params),
      new_orders_count: new_orders_count,
      processing_orders_count: processing_orders_count,
      waiting_conversations_count: waiting_conversations_count,
      low_stock_count: low_stock_count,
      merchant_attention_count: new_orders_count + waiting_conversations_count,
      is_order_filtered:
        normalize_optional_string(params["order_status"]) not in [nil, "all"] or
          normalize_optional_string(params["order_customer"]) != nil or
          normalize_optional_string(params["order_product"]) != nil,
      is_inventory_filtered:
        normalize_optional_string(params["inv_query"]) != nil or params["inv_low_stock"] == "true",
      is_conversation_filtered:
        normalize_optional_string(params["conv_customer"]) != nil or
          params["conv_waiting"] == "true",
      order_status: normalize_optional_string(params["order_status"]) || "all",
      order_customer_query: normalize_optional_string(params["order_customer"]) || "",
      order_product_query: normalize_optional_string(params["order_product"]) || "",
      inv_query: normalize_optional_string(params["inv_query"]) || "",
      inv_max_stock: if(params["inv_low_stock"] == "true", do: 25, else: nil),
      conv_customer_query: normalize_optional_string(params["conv_customer"]) || "",
      conv_needs_reply: if(params["conv_waiting"] == "true", do: true, else: nil),
      order_filters: %{
        status: normalize_optional_string(params["order_status"]) || "all",
        customer: normalize_optional_string(params["order_customer"]) || "",
        product: normalize_optional_string(params["order_product"]) || ""
      },
      inventory_filters: %{
        query: normalize_optional_string(params["inv_query"]) || "",
        low_stock: params["inv_low_stock"] == "true"
      },
      conversation_filters: %{
        customer: normalize_optional_string(params["conv_customer"]) || "",
        waiting: params["conv_waiting"] == "true"
      }
    }
  end
end
