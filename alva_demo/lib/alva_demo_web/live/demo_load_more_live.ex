defmodule AlvaDemoWeb.DemoLoadMoreLive do
  use AlvaDemoWeb, :live_view
  use Alva.LiveView, domains: [AlvaDemo.Academics]

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Alva.LiveView.subscribe(socket, "students:all")
    end

    socket =
      socket
      |> Alva.LiveView.activate_stream(:students)
      |> Alva.LiveView.bind_stream_query("students.list", :students, mode: :append)
      |> stream(:students, [])

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8 max-w-4xl mx-auto bg-gray-50 min-h-screen">
      <div class="mb-4">
        <.link navigate="/" class="text-blue-500 hover:underline">&larr; Back to Home</.link>
      </div>
      <h1 class="text-3xl font-bold mb-4">Load-More Demo (Query & Stream)</h1>
      <p class="mb-8 text-gray-600">This demo uses <code>bind_stream_query</code> to fetch paginated data and append it to an existing Stream collection.</p>

      <.vue component="DemoLoadMore" v-socket={@socket} students={@streams.students} />
    </div>
    """
  end
end
