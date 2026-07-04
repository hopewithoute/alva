defmodule AlvaDemoWeb.DataSync do
  import Phoenix.LiveView
  import Phoenix.Component

  @collection_topics [
    "order:created",
    "order:updated",
    "product:updated",
    "conversation:created"
  ]

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:support_messages, nil)
      |> Alva.LiveView.activate_stream(:support_messages)
      |> subscribe_route_topics()

    {:cont, socket}
  end

  # Collections own their source reads. This hook only connects PubSub updates and
  # the remaining non-collection support message stream.
  defp subscribe_route_topics(socket) do
    if connected?(socket) do
      Enum.reduce(["support_message:created" | @collection_topics], socket, fn topic, socket ->
        Alva.LiveView.subscribe(socket, topic)
      end)
    else
      socket
    end
  end
end
