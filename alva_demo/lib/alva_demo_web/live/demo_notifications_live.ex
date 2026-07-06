defmodule AlvaDemoWeb.DemoNotificationsLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    domains: [AlvaDemo.Demos],
    signals: ["demo_notifications.sent"],
    route_subscriptions: [
      {"demo_notifications.sent", ["demo_notification:sent"]}
    ]

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
