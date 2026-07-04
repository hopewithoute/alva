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
      |> assign(:products, load_collection(socket, "catalog.list_products"))
      |> assign(:conversations, load_collection(socket, "support.list_conversations"))
      |> assign(:support_messages, nil)
      |> Alva.LiveView.activate_stream(:products)
      |> Alva.LiveView.bind_stream_query("catalog.list_products", :products, mode: :reset)
      |> Alva.LiveView.activate_stream(:conversations)
      |> Alva.LiveView.bind_stream_query("support.list_conversations", :conversations,
        mode: :reset
      )
      |> Alva.LiveView.activate_stream(:support_messages)

    # We don't bind stream query for messages globally, client will fetch them manually per conversation
    # But the stream will push new messages.

    {:cont, socket}
  end

  defp load_collection(socket, event_name) do
    domains = get_in(socket.private, [:alva, :domains]) || []

    case Alva.Dispatcher.dispatch(event_name, %{}, domains: domains) do
      %{ok: true, data: data} when is_list(data) -> data
      _ -> []
    end
  end
end
