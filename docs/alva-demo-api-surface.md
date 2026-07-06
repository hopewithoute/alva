# Alva Demo API Surface

The commerce showcase should model the current Alva route-state API, not the
older route-owned assign plus legacy read-result binding workaround.

Route-owned lists are Alva Collections:

- `sales_orders`
- `products`
- `conversations`

Declare each list in the resource `live_vue` block with an explicit `source`
event, then activate it from the LiveView through `use Alva.LiveView,
collections: [...]`. At the render boundary, pass Collection state to Vue with
explicit stream props:

```elixir
<.vue
  v-component="MerchantConsolePage"
  sales_orders={@streams.sales_orders}
  products={@streams.products}
  conversations={@streams.conversations}
/>
```

Plain assigns are still appropriate for non-Collection props, especially state
that is not owned by the route as a full list. In this demo, support messages
are intentionally not a Collection because their history source depends on the
conversation selected in Vue. The chat surfaces fetch history with
`support.list_messages` for the active `conversation_id` and should use
raw Phoenix PubSub wiring for live `support_messages` pushes until that
behavior is modeled as a proper Collection or Signal. Declarative
`subscriptions:` and declarative `streams:` are not part of the recommended
public activation surface. Filter those live messages by the active
conversation before rendering the transcript.

Do not reintroduce route-owned list setup like:

- `assign(:products, load_collection(...))`
- `assign(:conversations, load_collection(...))`
- the removed `bind_stream_query("catalog.list_products", :products, ...)` bridge
- the removed `bind_stream_query("support.list_conversations", :conversations, ...)` bridge

If a route-owned list needs initial data plus realtime updates, make it a
Collection. If a future route truly needs route-dependent Collection input,
activate the Collection manually with explicit `source_input:` derived from
`Alva.LiveView.route_params(socket)` instead of hiding another route-owned list
loader behind an `on_mount` hook. Declarative `params:` is not part of the
supported activation surface.
