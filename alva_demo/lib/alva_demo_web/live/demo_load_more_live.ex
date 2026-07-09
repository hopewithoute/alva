defmodule AlvaDemoWeb.DemoLoadMoreLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    streams: [
      feed_entries: [
        resource: AlvaDemo.Demos.FeedEntry,
        source: :list,
        scope: %{page_limit: :feed_limit},
        sync_on: []
      ]
    ]

  def handle_params(params, _uri, socket) do
    limit =
      case Integer.parse(params["limit"] || "5") do
        {n, _} -> n
        :error -> 5
      end

    {:noreply, socket |> assign(feed_limit: limit) |> Alva.LiveView.reconfigure_streams(params)}
  end

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
