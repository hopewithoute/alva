# Alva Demo API Surface

The commerce showcase models the unified V2 Alva API, where realtime data delivery is completely decoupled from lifecycle intent.

Route-owned reactive data uses `subscriptions:` and `useAlvaStream`.
Transient notifications use `subscriptions:` and `useAlvaSignal`.

## 1. Backend Activation

Declare each capability in the resource `live_vue` block (e.g., `stream :sales_orders` or `signal :demo_notifications_sent`).

Then, activate it from the LiveView through the unified `subscriptions:` list:

```elixir
  use Alva.LiveView,
    subscriptions: [
      :sales_orders,
      :products,
      :conversations,
      :demo_notifications_sent
    ]

  def render(assigns) do
    ~H"""
    <.vue
      v-component="MerchantConsolePage"
      v-socket={@socket}
    />
    """
  end
```

At the render boundary, do **not** pass stream state to Vue with explicit props. Vue components must fetch the data using `useAlvaStream`.

## 2. Frontend Lifecycle

Inside the Vue component, use `useAlvaStream` to activate the stream on mount and deactivate on unmount.
The input payload is typed, and changes to the stream data are automatically managed by LiveVue via native LiveView streams:

```typescript
import { useAlvaStream } from "../../../js/alva/useAlvaStream";

useAlvaStream("sales_orders", {
  sort: "-created_at",
  status: null,
  customer_query: "",
  product_query: ""
});
```

For transient callbacks (e.g., notifications), use `useAlvaSignal`:

```typescript
import { useAlvaSignal } from "../../../js/alva/useAlvaSignal";

useAlvaSignal("demo_notifications_sent", {}, (payload) => {
  console.log("Received notification:", payload);
});
```

## 3. Infinite Scrolling (Load More)

To support infinite scrolling without destroying the subscription, `useAlvaStream` returns a controller object containing a `loadMore(params)` function. This tells the backend to fetch and stream_insert the next page of data while keeping the existing PubSub connection intact:

```typescript
const stream = useAlvaStream("feed_entries", { page: { limit: 5, offset: 0 } });

const handleLoadMore = () => {
  stream.loadMore({ page: { limit: 10, offset: 0 } });
};
```
