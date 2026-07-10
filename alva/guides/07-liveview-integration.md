# Phoenix LiveView Integration

The Alva frontend SDK communicates over WebSockets directly to your Phoenix LiveView instances. To handle this routing and seamlessly sync data, you must inject the `Alva.LiveView` module into your LiveView definitions.

## Integrating `Alva.LiveView`

In your `LiveView` module (e.g., `lib/my_app_web/live/storefront_live.ex`), simply `use Alva.LiveView` and define your stream synchronizations and uploads.

```elixir
defmodule MyAppWeb.StorefrontLive do
  use MyAppWeb, :live_view

  # 1. Mount Alva into the LiveView process
  use Alva.LiveView,
    # Configure auto-syncing streams
    streams: [
      products: [
        resource: MyApp.Catalog.Product,
        source: :list,
        scope: %{},
        sync_on: [:create, :adjust_stock, :destroy]
      ],
      orders: [
        resource: MyApp.Sales.Order,
        source: :my_orders,
        scope: %{user_id: :current_user_id},
        sync_on: [:create, :fulfill]
      ]
    ],
    # Automatically handle LiveView uploads linked to Alva forms
    uploads: ["catalog.upload_media"]

  def handle_params(params, _uri, socket) do
    # 2. Call reconfigure_streams/2 whenever route params change
    # to refresh data across your streams based on new parameters.
    {:noreply, socket |> Alva.LiveView.reconfigure_streams(params)}
  end

  def render(assigns) do
    ~H"""
    <.vue
      v-component="StorefrontPage"
      v-socket={@socket}
      
      <!-- 3. Pass the streams down to the Vue component -->
      products={Map.get(@streams, :products)}
      orders={Map.get(@streams, :orders)}
      media={@uploads.media}
    />
    """
  end
end
```

## How It Works

### Event Dispatching
By calling `use Alva.LiveView`, Alva dynamically intercepts incoming events (e.g., from `alva.catalog.create_product()` on the frontend) and routes them directly to the mapped Ash actions without writing any manual `handle_event/3` handlers!

### Reactive Streams
The `streams: [...]` config tells Alva to automatically re-fetch the stream (using the `source` action) whenever a mutation occurs locally or via PubSub (`sync_on`). 
- **`resource`**: The Ash resource to query.
- **`source`**: The `:read` action to use.
- **`scope`**: Parameters to pass into the read action. Values prefixed with a colon (e.g., `:current_user_id`) will dynamically map to values inside your LiveView socket assigns!
- **`sync_on`**: The mutation actions (create, update, destroy) that should trigger this stream to re-sync.

### Uploads
The `uploads: ["catalog.upload_media"]` array automatically configures `allow_upload/3` behind the scenes, linking the upload namespace so `alva.use_upload("catalog.upload_media")` on the frontend works out-of-the-box.
