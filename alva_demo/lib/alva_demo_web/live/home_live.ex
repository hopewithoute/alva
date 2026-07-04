defmodule AlvaDemoWeb.HomeLive do
  use AlvaDemoWeb, :live_view
  use Alva.LiveView, domains: [AlvaDemo.Academics]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Alva.LiveView.subscribe(socket, "students:all")
    end

    %{ok: true, data: students} = Alva.Dispatcher.dispatch("students.list", %{}, domains: [AlvaDemo.Academics])

    socket =
      socket
      |> Alva.LiveView.activate_stream(:students)
      |> Alva.LiveView.activate_signal("students.created")
      |> Alva.LiveView.bind_stream_query("students.list", :students, mode: :reset)
      |> stream(:students, students)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-10">
      <div class="max-w-2xl mx-auto mb-8 bg-white p-6 rounded-lg shadow-sm">
        <h2 class="text-2xl font-bold mb-4 text-gray-800">Alva Realtime Primitives Demos</h2>
        <ul class="flex gap-4">
          <li><.link navigate="/demo/chat" class="text-indigo-600 hover:underline bg-indigo-50 px-3 py-2 rounded-md">Chat Demo (Streams)</.link></li>
          <li><.link navigate="/demo/notifications" class="text-indigo-600 hover:underline bg-indigo-50 px-3 py-2 rounded-md">Notifications (Signals)</.link></li>
          <li><.link navigate="/demo/load-more" class="text-indigo-600 hover:underline bg-indigo-50 px-3 py-2 rounded-md">Load-More (Queries)</.link></li>
        </ul>
      </div>

      <.vue v-component="StudentsIndex" v-ssr={false} />
    </div>
    """
  end
end
