defmodule AlvaDemoWeb.HomeLive do
  use AlvaDemoWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-10">
      <.vue v-component="StudentsIndex" v-ssr={false} />
    </div>
    """
  end

  @impl true
  def handle_event(event, params, socket) do
    AlvaDemoWeb.Alva.dispatch(event, params, socket)
  end
end
