# Alva Demo V2 API Surface

This is the primary bridge-first walkthrough for the commerce showcase.

Read [ADR 0009](./adr/0009-alva-v2-stream-boundary-and-api.md) for the
architectural decision behind the stream boundary. Treat
`docs/phase-9-realtime-model.md` and `docs/alva-api-surface-analysis.md` as
compatibility or historical reference, not as the main V2 learning path.

## 1. Resource Contract

Declare command entrypoints with `event(...)` and realtime capabilities with
`subscription ... kind(:stream | :signal)` inside the resource `live_vue`
block:

```elixir
live_vue do
  event(:sales_list_orders, name: "sales.list_orders", action: :list)
  event(:sales_begin_processing, name: "sales.begin_processing", action: :begin_processing)

  subscription :sales_orders do
    name("sales_orders")
    kind(:stream)
    source(event: :sales_list_orders)
    scope(%{status: :string, customer_query: :string, product_query: :string, sort: :string})
    insert(on: :create, at: 0)
    update(on: :begin_processing)
    update(on: :fulfill)
    resolve(:resolve_sales_orders_scope)
  end

  subscription :demo_notifications_sent do
    name("demo_notifications_sent")
    kind(:signal)
    on(:send)
    resolve(:resolve_demo_notifications_scope)
  end
end
```

Streams describe server-owned list state. Signals describe non-list callbacks.

## 2. LiveView Activation

Pages expose an allowlist of capabilities with `use Alva.LiveView,
subscriptions: [...]`:

```elixir
use Alva.LiveView,
  subscriptions: [
    sales_orders: [activate: :mount],
    demo_notifications_sent
  ]

def render(assigns) do
  ~H"""
  <.vue
    v-component="MerchantConsolePage"
    v-socket={@socket}
    sales_orders={Map.get(@streams, :sales_orders)}
  />
  """
end
```

Three rules matter here:

- `activate: :mount` gives SSR-ready stream data without a loading flicker.
- `Map.get(@streams, :sales_orders)` is the canonical data boundary.
- The page allowlists activation, but the backend resolver still owns topic
  scope, source execution, and stream mutation.

## 3. Vue Stream Lifecycle

Vue uses `useAlvaStream(...)` only for lifecycle intent. The canonical list
still comes from props synced by LiveView and LiveVue:

```typescript
import { computed } from "vue";
import { useAlvaStream } from "alva";
import type { AlvaSubscriptions } from "./alva/subscriptions";

const props = defineProps<{
  support_messages?: SupportMessage[];
  active_conversation_id?: string | null;
}>();

useAlvaStream<AlvaSubscriptions>("support_messages", () => ({
  conversation_id: props.active_conversation_id || ""
}));

const messages = computed(() => props.support_messages ?? []);
```

`useAlvaStream(...)` may activate, reactivate, deactivate, and extend the
stream. It does not become a second client-owned data store.

When the input depends on reactive props or route-restored state, pass a getter
or ref so the subscription reactivates with the latest scope.

If the page eagerly rendered that stream on mount, the composable hydrates
against the existing prop instead of doing an unnecessary second activation.

## 4. Load More

`loadMore(...)` keeps the same stream boundary. Vue asks for a bigger slice,
the backend reruns the source, and LiveView grows the existing stream:

```typescript
const stream = useAlvaStream("feed_entries", {
  page: { limit: 5, offset: 0 },
  sort: "position"
});

const handleLoadMore = () => {
  stream.loadMore({
    page: { limit: 10, offset: 0 },
    sort: "position"
  });
};
```

The client still reads from props such as `props.feed_entries`, not from a
custom array owned by the composable.

## 5. Vue Signal Lifecycle

Signals are the sibling path for non-list realtime behavior:

```typescript
import { useAlvaSignal } from "alva";
import type { AlvaSubscriptions } from "./alva/subscriptions";

useAlvaSignal<AlvaSubscriptions>("demo_notifications_sent", {}, (payload) => {
  console.log("Received notification:", payload);
});
```

Use `useAlvaSignal` when the server should push semantic callbacks, not stream
state.

## 6. Compatibility Notes

The library still carries compatibility seams such as `page_events:`,
`page_state:`, and `usePageEvent` for
older migrations. The primary commerce showcase path no longer depends on
those helpers.

For new work and for the main docs path, prefer:

- resource `subscription` declarations
- LiveView `subscriptions:`
- `useAlvaStream`
- `useAlvaSignal`
- `useAlvaApi`
- `useAlvaUpload`
- `useAlvaForm`
