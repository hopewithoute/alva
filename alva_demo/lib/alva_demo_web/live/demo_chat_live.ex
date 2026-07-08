defmodule AlvaDemoWeb.DemoChatLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    subscriptions: [chat_messages: [activate: :mount]]

  def render(assigns) do
    ~H"""
    <.vue
      id="demo-chat-page"
      v-component="DemoChatPage"
      v-inject="layout"
      v-socket={@socket}
      chat_messages={Map.get(@streams, :chat_messages)}
    />
    """
  end
end
