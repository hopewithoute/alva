defmodule AlvaDemoWeb.DemoLoadMoreLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    collections: [
      {:feed_entries, source_input: :feed_entry_collection_source_input, reload_on: :route_change}
    ],
    route_subscriptions: [{:feed_entries, []}]

  def render(assigns) do
    ~H"""
    <.vue
      id="demo-load-more-page"
      v-component="DemoLoadMorePage"
      v-inject="layout"
      v-socket={@socket}
      feed_entries={@streams.feed_entries}
    />
    """
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  def feed_entry_collection_source_input(socket) do
    limit =
      socket
      |> Alva.LiveView.route_params()
      |> Map.get("limit", "5")
      |> String.to_integer()

    %{
      "page" => %{"limit" => limit, "offset" => 0},
      "sort" => "position"
    }
  end
end
