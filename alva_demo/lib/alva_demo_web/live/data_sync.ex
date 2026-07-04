defmodule AlvaDemoWeb.DataSync do
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      AlvaDemoWeb.Endpoint.subscribe("order:created")
      AlvaDemoWeb.Endpoint.subscribe("order:updated")
      AlvaDemoWeb.Endpoint.subscribe("product:updated")
      AlvaDemoWeb.Endpoint.subscribe("conversation:created")
      AlvaDemoWeb.Endpoint.subscribe("support_message:created")
    end

    socket =
      socket
      |> assign(:sales_orders, nil)
      |> assign(:products, nil)
      |> Alva.LiveView.activate_stream(:sales_orders)
      |> Alva.LiveView.bind_stream_query("sales.list_orders", :sales_orders)
      |> Alva.LiveView.activate_stream(:products)
      |> Alva.LiveView.bind_stream_query("catalog.list_products", :products)
      |> Alva.LiveView.activate_stream(:conversations)
      |> Alva.LiveView.bind_stream_query("support.list_conversations", :conversations)
      |> Alva.LiveView.activate_stream(:support_messages)
      # We don't bind stream query for messages globally, client will fetch them manually per conversation
      # But the stream will push new messages.

    {:cont, socket}
  end
end
