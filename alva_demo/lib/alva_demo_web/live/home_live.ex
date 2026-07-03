defmodule AlvaDemoWeb.HomeLive do
  use AlvaDemoWeb, :live_view
  use Alva.LiveView, domains: [AlvaDemo.Academics]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Alva.LiveView.subscribe(socket, "students:all")
    end

    socket =
      socket
      |> Alva.LiveView.activate_stream(:students)
      |> Alva.LiveView.activate_signal("students.created")
      |> Alva.LiveView.bind_stream_query("students.list", :students, mode: :reset)
      |> stream(:students, [])

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-10">
      <.vue v-component="StudentsIndex" v-ssr={false} />
    </div>
    """
  end
end
