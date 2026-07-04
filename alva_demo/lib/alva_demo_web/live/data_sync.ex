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
      |> assign(:support_messages, nil)
      |> Alva.LiveView.activate_stream(:support_messages)

    # We don't bind stream query for messages globally, client will fetch them manually per conversation
    # But the stream will push new messages.

    {:cont, socket}
  end
end
