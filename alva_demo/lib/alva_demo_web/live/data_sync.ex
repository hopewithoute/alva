defmodule AlvaDemoWeb.DataSync do
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      AlvaDemoWeb.Endpoint.subscribe("order:created")
      AlvaDemoWeb.Endpoint.subscribe("order:updated")
      AlvaDemoWeb.Endpoint.subscribe("product:updated")
    end

    socket =
      socket
      |> assign(:sales_orders, nil)
      |> assign(:products, nil)
      |> Alva.LiveView.activate_stream(:sales_orders)
      |> Alva.LiveView.bind_stream_query("sales.list_orders", :sales_orders)
      |> Alva.LiveView.activate_stream(:products)
      |> Alva.LiveView.bind_stream_query("catalog.list_products", :products)

    {:cont, socket}
  end
end
