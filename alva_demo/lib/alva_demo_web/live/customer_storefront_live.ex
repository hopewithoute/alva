defmodule AlvaDemoWeb.CustomerStorefrontLive do
  use AlvaDemoWeb, :live_view
  import AlvaDemoWeb.ParamHelpers

  use Alva.LiveView,
    subscriptions: [
      sales_orders: [activate: :mount],
      products: [activate: :mount],
      support_messages: [activate: :mount]
    ]

  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, storefront_route_assigns(params))}
  end

  def render(assigns) do
    ~H"""
    <.vue
      id="customer-storefront-page"
      v-component="CustomerStorefrontPage"
      v-inject="layout"
      v-socket={@socket}
      sales_orders={Map.get(@streams, :sales_orders)}
      products={Map.get(@streams, :products)}
      active_conversation_id={@active_conversation_id}
      connected_customer_name={@connected_customer_name}
      support_messages={Map.get(@streams, :support_messages)}
    />
    """
  end

  defp storefront_route_assigns(params) do
    %{
      active_conversation_id: normalize_conversation_id(params),
      connected_customer_name: normalize_customer_name(params)
    }
  end

  defp normalize_customer_name(params) when is_map(params) do
    params
    |> Map.get("customer_name")
    |> normalize_optional_string()
  end
end
