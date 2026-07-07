defmodule AlvaDemoWeb.MerchantConsoleLive do
  use AlvaDemoWeb, :live_view
  import AlvaDemoWeb.ParamHelpers

  use Alva.LiveView,
    collections: [
      sales_orders: [source_input: :sales_order_collection_source_input],
      products: [source_input: :product_collection_source_input],
      conversations: [source_input: :conversation_collection_source_input],
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
    page_state: :support_chat_page_state,
    page_events: [
      {"support.select_conversation", :select_conversation_page_event,
       %{
         input: "{ conversation_id: string }",
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
        |> Phoenix.LiveView.push_patch(to: console_conversation_path(conversation_id))

      {:reply, %{ok: true}, socket}
    end
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
    />
    """
  end

  def sales_order_collection_source_input, do: %{"sort" => "-created_at"}
  def product_collection_source_input, do: %{"sort" => "stock"}
  def conversation_collection_source_input, do: %{"sort" => "-last_message_at"}

  def support_chat_page_state(socket) do
    %{
      active_conversation_id: active_conversation_id(socket)
    }
  end

  def support_message_collection_source_input(socket) do
    %{"conversation_id" => active_conversation_id(socket)}
  end

  def support_message_route_topics(socket) do
    case active_conversation_id(socket) do
      nil -> {:ok, []}
      conversation_id -> {:ok, ["support_message:conversation:#{conversation_id}"]}
    end
  end

  defp console_conversation_path(nil), do: ~p"/console"

  defp console_conversation_path(conversation_id),
    do: ~p"/console?#{%{conversation_id: conversation_id}}"

  defp active_conversation_id(socket) do
    socket
    |> Alva.LiveView.route_params()
    |> normalize_conversation_id()
  end
end
