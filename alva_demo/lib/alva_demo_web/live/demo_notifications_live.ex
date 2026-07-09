defmodule AlvaDemoWeb.DemoNotificationsLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    streams: [
      notifications: [
        resource: AlvaDemo.Demos.Notification,
        source: :read,
        scope: %{},
        sync_on: [:send]
      ]
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
