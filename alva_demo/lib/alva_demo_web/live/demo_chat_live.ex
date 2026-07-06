defmodule AlvaDemoWeb.DemoChatLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    collections: [:chat_messages]

  def render(assigns) do
    ~H"""
    <.vue
      id="demo-chat-page"
      v-component="DemoChatPage"
      v-inject="layout"
      v-socket={@socket}
      chat_messages={@streams.chat_messages}
    />
    """
  end
end
