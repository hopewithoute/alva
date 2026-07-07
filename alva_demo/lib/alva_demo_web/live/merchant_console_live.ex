defmodule AlvaDemoWeb.MerchantConsoleLive do
  use AlvaDemoWeb, :live_view
  import AlvaDemoWeb.ParamHelpers

  use Alva.LiveView,
    subscriptions: [
      :sales_orders,
      :products,
      :conversations,
      :support_messages
    ],
    page_state: :console_page_state,
    page_events: [
      {"support.select_conversation", :select_conversation_page_event, %{conversation_id: :string}},
      {"console.filter_orders", :filter_orders_page_event, %{status: :string, customer_query: :string, product_query: :string}},
      {"console.filter_inventory", :filter_inventory_page_event, %{query: :string, low_stock_only: :boolean}},
      {"console.filter_conversations", :filter_conversations_page_event, %{customer_query: :string, waiting_on_merchant_only: :boolean}}
    ]

  def select_conversation_page_event(%{"conversation_id" => conversation_id}, socket) do
    conversation_id = conversation_id |> to_string() |> String.trim()

    if conversation_id == "" do
      {:reply, %{ok: false, error: %{message: "Select a conversation first."}}, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.push_patch(to: console_conversation_path(conversation_id, Alva.LiveView.route_params(socket)))

      {:reply, %{ok: true}, socket}
    end
  end

  def filter_orders_page_event(params, socket) do
    current = Alva.LiveView.route_params(socket)
    
    new_params =
      current
      |> Map.put("order_status", params["status"])
      |> Map.put("order_customer", params["customer_query"])
      |> Map.put("order_product", params["product_query"])

    socket = Phoenix.LiveView.push_patch(socket, to: ~p"/console?#{new_params}")
    {:reply, %{ok: true}, socket}
  end

  def filter_inventory_page_event(params, socket) do
    current = Alva.LiveView.route_params(socket)
    
    new_params =
      current
      |> Map.put("inv_query", params["query"])
      |> Map.put("inv_low_stock", if(params["low_stock_only"], do: "true", else: nil))

    socket = Phoenix.LiveView.push_patch(socket, to: ~p"/console?#{new_params}")
    {:reply, %{ok: true}, socket}
  end

  def filter_conversations_page_event(params, socket) do
    current = Alva.LiveView.route_params(socket)
    
    new_params =
      current
      |> Map.put("conv_customer", params["customer_query"])
      |> Map.put("conv_waiting", if(params["waiting_on_merchant_only"], do: "true", else: nil))

    socket = Phoenix.LiveView.push_patch(socket, to: ~p"/console?#{new_params}")
    {:reply, %{ok: true}, socket}
  end

  def render(assigns) do
    ~H"""
    <.vue
      id="merchant-console-page"
      v-component="MerchantConsolePage"
      v-inject="layout"
      v-socket={@socket}
      media={@uploads.media}
      active_conversation_id={@active_conversation_id}
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



  def console_page_state(socket) do
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

    params = Alva.LiveView.route_params(socket)

    %{
      active_conversation_id: active_conversation_id(socket),
      new_orders_count: new_orders_count,
      processing_orders_count: processing_orders_count,
      waiting_conversations_count: waiting_conversations_count,
      low_stock_count: low_stock_count,
      merchant_attention_count: new_orders_count + waiting_conversations_count,
      is_order_filtered: normalize_optional_string(params["order_status"]) not in [nil, "all"] or normalize_optional_string(params["order_customer"]) != nil or normalize_optional_string(params["order_product"]) != nil,
      is_inventory_filtered: normalize_optional_string(params["inv_query"]) != nil or params["inv_low_stock"] == "true",
      is_conversation_filtered: normalize_optional_string(params["conv_customer"]) != nil or params["conv_waiting"] == "true",
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

  defp console_conversation_path(nil, current_params), do: ~p"/console?#{current_params |> Map.delete("conversation_id")}"

  defp console_conversation_path(conversation_id, current_params),
    do: ~p"/console?#{Map.put(current_params, "conversation_id", conversation_id)}"

end
