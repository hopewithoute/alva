defmodule AlvaDemoWeb.MerchantConsoleLive do
  use AlvaDemoWeb, :live_view
  import AlvaDemoWeb.ParamHelpers

  use Alva.LiveView,
    collections: [
      sales_orders: [
        source_input: :sales_order_collection_source_input,
        reload_on: :route_change
      ],
      products: [
        source_input: :product_collection_source_input,
        reload_on: :route_change
      ],
      conversations: [
        source_input: :conversation_collection_source_input,
        reload_on: :route_change
      ],
      support_messages: [
        source_input: :support_message_collection_source_input,
        reload_on: :route_change
      ]
    ],
    route_subscriptions: [
      {:sales_orders, ["order:created", "order:updated"]},
      {:products, ["product:updated"]},
      {:conversations, ["conversation:created", "conversation:updated"]},
      {:support_messages, :support_message_route_topics}
    ],
    page_state: :console_page_state,
    page_events: [
      {"support.select_conversation", :select_conversation_page_event,
       %{
         input: "{ conversation_id: string }",
         output: "void"
       }},
      {"console.filter_orders", :filter_orders_page_event,
       %{
         input: "{ status?: string, customer_query?: string, product_query?: string }",
         output: "void"
       }},
      {"console.filter_inventory", :filter_inventory_page_event,
       %{
         input: "{ query?: string, low_stock_only?: boolean }",
         output: "void"
       }},
      {"console.filter_conversations", :filter_conversations_page_event,
       %{
         input: "{ customer_query?: string, waiting_on_merchant_only?: boolean }",
         output: "void"
       }}
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
      sales_orders={@streams.sales_orders}
      products={@streams.products}
      conversations={@streams.conversations}
      active_conversation_id={@active_conversation_id}
      support_messages={@streams.support_messages}
      new_orders_count={@new_orders_count}
      processing_orders_count={@processing_orders_count}
      waiting_conversations_count={@waiting_conversations_count}
      merchant_attention_count={@merchant_attention_count}
      is_order_filtered={@is_order_filtered}
      is_inventory_filtered={@is_inventory_filtered}
      is_conversation_filtered={@is_conversation_filtered}
      low_stock_count={@low_stock_count}
      route_filters={@route_filters}
    />
    """
  end

  def sales_order_collection_source_input(socket) do
    params = Alva.LiveView.route_params(socket)
    status = normalize_optional_string(params["order_status"])
    status = if status in ["new", "processing", "fulfilled"], do: String.to_atom(status), else: nil

    %{
      "sort" => "-created_at",
      "status" => status,
      "customer_query" => normalize_optional_string(params["order_customer"]),
      "product_query" => normalize_optional_string(params["order_product"])
    }
  end

  def product_collection_source_input(socket) do
    params = Alva.LiveView.route_params(socket)
    
    %{
      "sort" => "stock",
      "query" => normalize_optional_string(params["inv_query"]),
      "max_stock" => if(params["inv_low_stock"] == "true", do: 25, else: nil)
    }
  end

  def support_message_collection_source_input(socket) do
    %{"conversation_id" => normalize_conversation_id(Alva.LiveView.route_params(socket))}
  end

  def support_message_route_topics(socket) do
    case normalize_conversation_id(Alva.LiveView.route_params(socket)) do
      nil -> {:ok, []}
      conversation_id -> {:ok, ["support_message:conversation:#{conversation_id}"]}
    end
  end

  def conversation_collection_source_input(socket) do
    params = Alva.LiveView.route_params(socket)
    
    %{
      "sort" => "-last_message_at",
      "customer_query" => normalize_optional_string(params["conv_customer"]),
      "needs_merchant_reply" => if(params["conv_waiting"] == "true", do: true, else: nil)
    }
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
      route_filters: %{
        order_status: normalize_optional_string(params["order_status"]) || "all",
        order_customer: normalize_optional_string(params["order_customer"]) || "",
        order_product: normalize_optional_string(params["order_product"]) || "",
        inv_query: normalize_optional_string(params["inv_query"]) || "",
        inv_low_stock: params["inv_low_stock"] == "true",
        conv_customer: normalize_optional_string(params["conv_customer"]) || "",
        conv_waiting: params["conv_waiting"] == "true"
      }
    }
  end

  defp console_conversation_path(nil, current_params), do: ~p"/console?#{current_params |> Map.delete("conversation_id")}"

  defp console_conversation_path(conversation_id, current_params),
    do: ~p"/console?#{Map.put(current_params, "conversation_id", conversation_id)}"

end
