defmodule AlvaDemoWeb.DemoChatLive do
  use AlvaDemoWeb, :live_view
  use Alva.LiveView, domains: [AlvaDemo.Communication]

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Alva.LiveView.subscribe(socket, "messages:all")
    end

    messages = AlvaDemo.Communication.Message.read!()

    socket = 
      socket
      |> Alva.LiveView.activate_stream(:messages)
      |> stream(:messages, messages)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8 max-w-4xl mx-auto bg-gray-50 min-h-screen">
      <div class="mb-4">
        <.link navigate="/" class="text-blue-500 hover:underline">&larr; Back to Home</.link>
      </div>
      <h1 class="text-3xl font-bold mb-4">Chat Demo (Streams)</h1>
      <p class="mb-8 text-gray-600">This demo uses <code>Ash.Notifier.PubSub</code> and LiveVue streams to instantly sync messages across all clients.</p>

      <.vue component="DemoChat" v-socket={@socket} messages={@streams.messages} />
    </div>
    """
  end
end
