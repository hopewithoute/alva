defmodule AlvaDemoWeb.DocsLive do
  use AlvaDemoWeb, :live_view

  def handle_params(params, _uri, socket) do
    slug = Map.get(params, "slug", "getting-started")
    {:noreply, assign(socket, :slug, slug)}
  end

  def render(assigns) do
    ~H"""
    <.vue
      id="docs-page"
      v-component="DocsPage"
      v-inject="layout"
      v-socket={@socket}
      slug={@slug}
    />
    """
  end
end
