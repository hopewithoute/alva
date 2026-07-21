defmodule AlvaDemoWeb.DemoQueryLookupLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    streams: [
      products: [
        resource: AlvaDemo.Catalog.Product,
        source: :list,
        sync_on: [:adjust_stock, :upload_media]
      ]
    ]

  def render(assigns) do
    ~H"""
    <.vue
      id="demo-query-lookup-page"
      v-component="DemoQueryLookupPage"
      v-inject="layout"
      v-socket={@socket}
      products={Map.get(@streams, :products)}
    />
    """
  end
end
