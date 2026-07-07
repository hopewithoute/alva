defmodule AlvaDemoWeb.DemoNotificationsLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    subscriptions: [:demo_notifications_sent]

  def render(assigns) do
    ~H"""
    <.vue
      id="demo-notifications-page"
      v-component="DemoNotificationsPage"
      v-inject="layout"
      v-socket={@socket}
    />
    """
  end
end
