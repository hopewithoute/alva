defmodule AlvaDemoWeb.DemoChatLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    subscriptions: [:chat_messages]

  def render(assigns) do
    ~H"""
    <.vue
      id="demo-chat-page"
      v-component="DemoChatPage"
      v-inject="layout"
      v-socket={@socket}
    />
    """
  end
end
