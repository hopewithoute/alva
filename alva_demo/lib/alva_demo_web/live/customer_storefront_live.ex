defmodule AlvaDemoWeb.CustomerStorefrontLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    collections: [
      sales_orders: [source_input: :sales_order_collection_source_input],
      products: [source_input: :product_collection_source_input]
    ]

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:support_messages, [])
      |> maybe_subscribe_support_messages()

    {:ok, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "support_message:created",
          event: "create",
          payload: %Ash.Notifier.Notification{data: data}
        },
        socket
      ) do
    {:noreply, update(socket, :support_messages, &upsert_support_message(&1, data))}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

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

  defp maybe_subscribe_support_messages(socket) do
    if Phoenix.LiveView.connected?(socket) do
      :ok = AlvaDemoWeb.Endpoint.subscribe("support_message:created")
      socket
    else
      socket
    end
  end

  defp upsert_support_message(messages, data) do
    message = Alva.Dispatcher.strip_metadata(data)
    message_id = message.id
    messages = messages || []

    if Enum.any?(messages, &(&1.id == message_id)) do
      Enum.map(messages, fn
        %{id: ^message_id} -> message
        existing -> existing
      end)
    else
      messages ++ [message]
    end
  end
end
