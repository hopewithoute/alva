defmodule AlvaDemoWeb.DemoOptimisticFormLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    streams: [
      products: [
        resource: AlvaDemo.Catalog.Product,
        source: :list,
        sync_on: [:adjust_stock]
      ]
    ]

  def render(assigns) do
    ~H"""
    <.vue
      id="demo-optimistic-form-page"
      v-component="DemoOptimisticFormPage"
      v-inject="layout"
      v-socket={@socket}
      products={Map.get(@streams, :products)}
    />
    """
  end
end
