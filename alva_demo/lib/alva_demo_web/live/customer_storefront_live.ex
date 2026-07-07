defmodule AlvaDemoWeb.CustomerStorefrontLive do
  use AlvaDemoWeb, :live_view
  import AlvaDemoWeb.ParamHelpers

  use Alva.LiveView,
    subscriptions: [
      :sales_orders,
      :products,
      :support_messages
    ],
    page_state: :support_chat_page_state,
    page_events: [
      {"storefront.set_identity", :set_identity_page_event, %{customer_name: :string}},
      {"support.join_chat", :join_chat_page_event, %{customer_name: :string}},
      {"support.reset_chat", :reset_chat_page_event, %{}}
    ]

  def set_identity_page_event(%{"customer_name" => customer_name}, socket) do
    customer_name = customer_name |> to_string() |> String.trim()
    
    conversation_id = 
      case Alva.Dispatcher.dispatch("support.get_conversation", %{"customer_name" => customer_name}, socket: socket) do
        %{ok: true, data: conversation} when not is_nil(conversation) -> conversation.id
        _ -> active_conversation_id(socket)
      end

    params = %{customer_name: customer_name, conversation_id: conversation_id}
    
    # Clean up empty params
    params = params |> Enum.reject(fn {_, v} -> is_nil(v) or v == "" end) |> Enum.into(%{})
    
    socket = Phoenix.LiveView.push_patch(socket, to: ~p"/storefront?#{params}")
    {:reply, %{ok: true}, socket}
  end

  def join_chat_page_event(%{"customer_name" => customer_name}, socket) do
    customer_name = customer_name |> to_string() |> String.trim()

    if customer_name == "" do
      {:reply, %{ok: false, error: %{message: "Enter your name before joining chat."}}, socket}
    else
      case Alva.Dispatcher.dispatch("support.create", %{"customer_name" => customer_name},
             socket: socket
           ) do
        %{ok: true, data: conversation} ->
          socket =
            socket
            |> Phoenix.LiveView.push_patch(
              to: storefront_chat_path(conversation.id, customer_name)
            )

          {:reply, %{ok: true}, socket}

        %{ok: false, error: error} ->
          {:reply, %{ok: false, error: error}, socket}
      end
    end
  end

  def reset_chat_page_event(_params, socket) do
    socket =
      socket
      |> Phoenix.LiveView.push_patch(to: storefront_chat_path(nil, nil))

    {:reply, %{ok: true}, socket}
  end

  def render(assigns) do
    ~H"""
    <.vue
      id="customer-storefront-page"
      v-component="CustomerStorefrontPage"
      v-inject="layout"
      v-socket={@socket}
      active_conversation_id={@active_conversation_id}
      connected_customer_name={@connected_customer_name}
    />
    """
  end

  def support_chat_page_state(socket) do
    %{
      active_conversation_id: active_conversation_id(socket),
      connected_customer_name: connected_customer_name(socket)
    }
  end

  defp storefront_chat_path(nil, _customer_name), do: ~p"/storefront"

  defp storefront_chat_path(conversation_id, customer_name) do
    ~p"/storefront?#{%{conversation_id: conversation_id, customer_name: customer_name}}"
  end

  defp connected_customer_name(socket) do
    socket
    |> Alva.LiveView.route_params()
    |> normalize_customer_name()
  end

  defp normalize_customer_name(params) when is_map(params) do
    params
    |> Map.get("customer_name")
    |> normalize_optional_string()
  end
end
