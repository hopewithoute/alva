defmodule AlvaDemoWeb.DemoChatLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    streams: [
      chat_messages: [
        resource: AlvaDemo.Demos.ChatMessage,
        source: :list,
        scope: %{},
        sync_on: [:send]
      ]
    ]

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
