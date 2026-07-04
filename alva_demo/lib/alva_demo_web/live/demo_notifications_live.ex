defmodule AlvaDemoWeb.DemoNotificationsLive do
  use AlvaDemoWeb, :live_view
  use Alva.LiveView, domains: [AlvaDemo.Communication]

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Alva.LiveView.subscribe(socket, "notifications:all")
    end

    socket =
      socket
      |> Alva.LiveView.activate_signal("notifications.created")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8 max-w-4xl mx-auto bg-gray-50 min-h-screen">
      <div class="mb-4">
        <.link navigate="/" class="text-blue-500 hover:underline">&larr; Back to Home</.link>
      </div>
      <h1 class="text-3xl font-bold mb-4">Notifications Demo (Signals)</h1>
      <p class="mb-8 text-gray-600">This demo uses <code>bind_signal</code> to show ephemeral toast notifications dispatched by the server.</p>

      <.vue component="DemoNotifications" v-socket={@socket} />
    </div>
    """
  end
end
