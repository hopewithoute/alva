defmodule AlvaDemoWeb.DemoLoadMoreLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    streams: [
      feed_entries: [
        resource: AlvaDemo.Demos.FeedEntry,
        source: :list,
        scope: %{},
        sync_on: []
      ]
    ]

  def render(assigns) do
    ~H"""
    <.vue
      id="demo-load-more-page"
      v-component="DemoLoadMorePage"
      v-inject="layout"
      v-socket={@socket}
      feed_entries={Map.get(assigns[:streams] || %{}, :feed_entries)}
    />
    """
  end
end
