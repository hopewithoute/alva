defmodule AlvaDemoWeb.DemoChatLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    domains: [AlvaDemo.Demos],
    streams: [:chat_messages],
    subscriptions: ["demo_chat:created"]

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :chat_messages, initial_messages())}
  end

  def render(assigns) do
    ~H"""
    <.vue
      id="demo-chat-page"
      v-component="DemoChatPage"
      v-inject="layout"
      v-socket={@socket}
      chat_messages={@chat_messages}
    />
    """
  end

  defp initial_messages do
    case Alva.Dispatcher.dispatch("demo_chat.list_messages", %{}, domains: [AlvaDemo.Demos]) do
      %{ok: true, data: data} -> data
      _ -> []
    end
  end
end
