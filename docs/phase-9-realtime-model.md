# Alva Realtime Model (Phase 9 Legacy Runtime Reference)

> Legacy page-owned runtime reference.
> Start with [ADR 0009](./adr/0009-alva-v2-stream-boundary-and-api.md) and
> [docs/alva-demo-api-surface.md](./alva-demo-api-surface.md) for the supported
> V2 bridge-first teaching path. This document is kept for compatibility and
> migration work around older `collections:`, `signals:`, `route_subscriptions:`,
> `page_events:`, and `page_state:` seams.

## Overview

Based on ADR 0002 and ADR 0003, Alva's realtime communication model separates concerns into **Commands**, **Route Subscriptions**, **Collections**, **Route Collections**, **Signals**, **Resource Projections**, and **Page Projections**.

This separation explicitly maps resource-level definitions to page-level (route-level) activations, keeping collection synchronization cleanly on the server (via Phoenix stream operations and LiveVue diffs) while preserving semantic signals and ad hoc commands for the client.

Traceability follows one Ash-native chain:

* **Action**: the Ash operation, such as `:create` or `:fulfill`
* **Publication**: the `publish(...)` declaration attached to that Action
* **Event**: the published occurrence name, such as `"order.fulfilled"`
* **Topic**: the routing scope, such as `"orders:all"`
* **Projection Trigger**: the Collection/Signal `on:` value, which points to the PubSub occurrence key, such as `:fulfill`
* **Route Subscription**: the page-level Topic wiring that decides whether that Event can reach the page

### Vocabulary

* **Command**: A Vue-to-server request/reply interaction (e.g., `ash.ashCall('orders.create', {...})`). It provides immediate, normalized feedback to the caller but does not directly broadcast realtime state changes to other clients.
* **Declaration Key**: The internal atom identifier for an Alva declaration. Resource wiring and route activation refer to declaration keys.
* **Exposed Name**: The client-facing string that crosses the Vue boundary. Commands call exposed event names, and `ash.on()` listens to exposed signal names.
* **Route Subscription**: A page-level declarative projection wiring indicating which PubSub topics a given LiveView page cares about (e.g., `route_subscriptions: [{:sales_orders, ["orders:all"]}]`). Route Subscriptions define scope only; they do not by themselves choose whether an incoming occurrence becomes a Collection update or a Signal callback.
* **Collection**: A server-owned reactive list defined in an Ash Resource's `live_vue` block. It must declare an explicit Collection Source for initial/reset data and may map PubSub occurrence keys (via `on:`) to Phoenix LiveStream operations that LiveVue delivers as stream diffs. A Collection is source snapshot plus optional occurrence-triggered deltas. A Collection with no insert/update/delete mappings is source-only and should produce a warning.
* **Stream**: The internal Phoenix LiveStream/LiveVue stream-diff transport used for Collections. It is not the public DSL name.
* **Route Collection**: A collection of data initialized and maintained server-side (often pushed via `stream(:students, data)`) and synchronized out to the subscribed route's LiveVue instances automatically.
* **Route Params**: URL and path params delivered by Phoenix route lifecycle callbacks such as `handle_params/3`. Route Params describe page state, not Ash action input.
* **Collection Source**: The required `source` declaration inside a Collection that loads or rebuilds the Collection snapshot.
* **Source Input**: The payload a route sends to a Collection Source when activating or refreshing that Collection. Source Input may be derived from Route Params, session assigns, actor/tenant context, or route-local defaults.
* **Collection Refresh**: A route-level re-run of a Collection Source with current Source Input that replaces or resets the active Collection server-side.
* **Route Change Reload**: Automatic Collection Refresh triggered by a route lifecycle change, usually because Route Params changed.
* **Signal**: A semantic, non-collection callback event delivered to Vue via `ash.on('event', payload)` (e.g., toast notifications, generic broadcast triggers).
* **Resource Projection**: The foundational block inside an Ash Resource (the Collection Block or Signal Block) dictating what happens when a published Event fires. Legacy stream projections may still exist in current code, but the public domain language should prefer Collection for route-owned list state.
* **Page Projection**: The active realization of a resource projection on a specific route, instantiated via `Alva.LiveView.collection/2` or `activate_signal/2`.

---

## Defining Resource Projections

Define collections and signals within the `live_vue` block of your Ash Resource. The `source event:` mapping references an Alva command/read Event Declaration because it loads a snapshot. The `on:` mappings reference PubSub occurrence keys from the `pub_sub` block because they react to notifications. Topic scope belongs to page activation, not to the projection definition.

```elixir
defmodule MyApp.Sales.Order do
  use Ash.Resource, extensions: [Alva.Resource, Ash.Notifier.PubSub]
  
  pub_sub do
    module MyAppWeb.Endpoint
    prefix "orders"
    publish :create, ["all"], event: "order.created"
    publish :fulfill, ["all"], event: "order.fulfilled"
    publish :cancel, ["all"], event: "order.cancelled"
  end

  live_vue do
    event :list_orders,
      name: "orders.list",
      action: :list

    event :create_order,
      name: "orders.create",
      action: :create

    event :fulfill_order,
      name: "orders.fulfill",
      action: :fulfill

    event :cancel_order,
      name: "orders.cancel",
      action: :cancel

    # Collection Block (Resource Projection)
    collection :sales_orders do
      source event: :list_orders, mode: :reset
      insert on: :create, at: 0, limit: -20
      update on: :fulfill, update_only: true
      delete on: :cancel
    end

    # Signal Block (Resource Projection)
    signal :order_fulfilled,
      name: "order.fulfilled",
      on: :fulfill
  end
end
```

---

## Activating Page Projections And Route Subscriptions

On your LiveView (the page level), hook into `Alva.LiveView` to wire Topics and activate only the projections you need for that route.

### Deterministic Default Case

When the Topic set is static and unambiguous, the page can stay fully declarative and let Alva infer the Topic wiring. The Collection still owns its required source. A projection trigger must resolve through one unambiguous publication path; if it matches more than one publication, the page must declare `route_subscriptions:` explicitly even when the resulting Topic union would be static. A single publication may still expand into several Topics and remain deterministic when that expansion is static and declaration-derived.

```elixir
defmodule MyAppWeb.SalesOrdersLive do
  use MyAppWeb, :live_view
  use Alva.LiveView,
    domains: [MyApp.Sales],
    collections: [
      sales_orders: [source_input: %{status: "open"}]
    ],
    signals: [:order_fulfilled]
end
```

If a page wants static explicit wiring instead of inference, it can add:

```elixir
route_subscriptions: [
  {:sales_orders, ["orders:all"]},
  {:order_fulfilled, ["orders:all"]}
]
```

An explicit empty list is authoritative and disables realtime Topic wiring for
that projection without falling back to inference:

```elixir
route_subscriptions: [
  {:sales_orders, []}
]
```

The same semantics apply to callback-driven overrides: returning `[]` is an
authoritative dynamic opt-out for that page scope, not a signal to resume
inference.

`nil` is invalid for the callback contract and should raise loudly rather than
behaving like an implicit empty topic list.

### Dynamic Case

When Topic scope depends on Page Scope such as route params, actor, tenant, or permission checks, the page keeps the same projection activation and makes only the Topic wiring dynamic:

```elixir
defmodule MyAppWeb.SalesOrdersLive do
  use MyAppWeb, :live_view
  use Alva.LiveView,
    domains: [MyApp.Sales],
    collections: [
      sales_orders: [
        source_input: :sales_order_source_input,
        reload_on: :route_change
      ]
    ],
    signals: [:order_fulfilled],
    route_subscriptions: [
      {:sales_orders, :sales_order_topics},
      {:order_fulfilled, :order_fulfilled_topics}
    ]

  def sales_order_source_input(socket) do
    route = Alva.LiveView.route_params(socket)

    %{
      "status" => route["status"]
    }
  end

  def sales_order_topics(socket) do
    if can_view_orders?(socket) do
      {:ok, ["orders:tenant:#{socket.assigns.current_tenant.slug}"]}
    else
      {:ok, []}
    end
  end

  def order_fulfilled_topics(socket) do
    sales_order_topics(socket)
  end
end
```

Callbacks may consult Page Scope and permission checks such as `Ash.can?`, but declarative activation must stay configuration-only. Redirects, 404 handling, or branchy flow still belong to imperative activation or plain Phoenix callbacks.

No Collection or PubSub subscription is activated merely because its domain is mounted. The `collections: [...]` and `signals: [...]` options activate projections. `route_subscriptions:` wires Topics for those projections. Route Subscriptions decide which Topics reach the page, while Collection and Signal activation decide how matching Events are projected. The render boundary remains explicit: Vue receives `@streams.collection_name` as a prop.

Collection activation supports Source Input from the start. If no Source Input is provided, Alva dispatches the Collection Source with `%{}`. Simple pages may use static Source Input in `collections: [...]`; advanced pages may use local callback names for DB-backed or route-dependent Source Input and topics. `source_input:` is the only valid declarative Collection input key; legacy `params:` is invalid and should raise loudly. Manual helpers remain available for conditional activation, graceful not-found handling, custom subscription lifecycles, and complex multi-step setup.

Route Params and Source Input are intentionally separate. Route Params belong to the page URL. Source Input belongs to the Collection Source. A route may derive Source Input from Route Params, but Alva should not call both of them plain `params`.

Route-owned Collections that need URL-driven filtering or pagination should opt into route-change reload at route activation. The resource-level `collection` block only declares the reusable capability; route activation owns the current Source Input and whether the Collection reloads on route changes:

```elixir
use Alva.LiveView,
  domains: [MyApp.Sales],
  collections: [
    sales_orders: [
      source_input: :sales_order_source_input,
      reload_on: :route_change
    ]
  ]

def sales_order_source_input(socket) do
  route = Alva.LiveView.route_params(socket)

  %{
    "status" => route["orders_status"]
  }
end
```

With route-change reload, Alva owns the Collection Refresh mechanics while the app still owns URL semantics.

Activation callbacks may return a raw value or `{:ok, value}`. Returning `{:error, reason}` raises an activation error because declarative activation is a fail-loud page setup path, not user-facing validation. If a route needs graceful 404, redirect, or conditional behavior, use manual `mount` branching before activating the Collection.

Collection Sources do not declare result shape. Alva uses the source event's Auto-DTO/projection contract as the source of truth for the records to stream. Standard resource lists and supported Ash page-like results stream their records automatically; custom DTO envelopes used as Collection Sources must make their record field clear in the DTO/projection layer. If Alva cannot determine records, Collection activation fails with an actionable message naming the collection and source event.

Collections lean on Phoenix LiveView stream semantics instead of reimplementing list reconciliation. Identity is handled by LiveView `dom_id`, defaulting to `item.id`; custom DTO projections may use stream configuration if they need a custom DOM identity. Duplicate handling is handled by `stream_insert` plus LiveVue upsert, so the caller's immediate command update and the later PubSub echo do not create duplicate DOM records.

Insert operations must declare `at:` explicitly and use Phoenix LiveView stream index semantics directly: `at: 0` inserts at the beginning, `at: -1` appends at the end, and other integers are passed through to LiveView. Alva does not infer insert position from source data ordering; sorted or filtered Collections that cannot safely accept positional inserts should use a source refresh operation instead.

Update operations map to `stream_insert(..., update_only: true)` by default, which updates existing items without inserting missing items. If a Collection intentionally wants an update occurrence to insert missing items, it can opt into the native LiveView behavior with `update_only: false` and provide any needed `at:`/`limit:` options directly.

---

## Vue Frontend Implementation

Because LiveVue stream diffs automatically synchronize the Collection prop, the Vue component no longer manually pushes or splices arrays for route-owned collections:

```vue
<template>
  <div />
</template>

<script setup lang="ts">
import { useAlvaApi } from 'alva'

// The Collection prop is managed by the server through LiveVue stream diffs.
const props = defineProps<{ sales_orders: SalesOrder[] }>()

const ash = useAlvaApi<AlvaEvents, SignalEvents>()

// Signal usage for a non-collection callback
ash.on('order.fulfilled', (payload) => {
  alert(`Toast: Order fulfilled: ${payload.data.reference}`)
})

const create_order = async () => {
  // Command mutation provides immediate feedback
  const reply = await ash.ashCall('orders.create', { reference: "SO-1001" })
  
  if (reply.ok) {
    // DO NOT MANUALLY UPDATE props.sales_orders!
    // The server handles the Route Collection via Phoenix LiveStream + LiveVue.
  }
}

</script>
```

---

## Migration Notes (Upgrading to Phase 9)

When migrating older components to the Phase 9 architecture, observe the following rules:

1. **Stop using `ashQuery` stream reconciliation.**
   Route-owned collections must use Phoenix stream operations plus LiveVue stream diffs. Do **not** use `ashQuery` stream insert/delete callback reconciliation. The `updateArray` logic and stream callbacks in `ashQuery` have been completely removed.
2. **Move Collection State to Props.**
   Instead of holding an array in `ref<SalesOrder[]>([])` and querying it `onMounted`, declare a `defineProps<{ sales_orders: SalesOrder[] }>()` and let LiveVue supply the stream data initialized by the LiveView.
   In the LiveView render, pass the server-owned stream explicitly:

   ```elixir
   <.vue v-component="SalesOrdersPage" sales_orders={@streams.sales_orders} />
   ```

   Remove temporary `v-diff={false}` workarounds and plain list assigns such as `assign(:sales_orders, ...)` once the route-owned list is an Alva Collection. Plain assigns are still fine for non-Collection props.
3. **Use Explicit Collection Sources.**
   Every Collection must declare its initial load/reset path with `source event: ...`. If you need refresh, pagination, or filtering, treat them as route-level Collection concerns and re-run the Collection Source server-side with the desired Source Input instead of binding command read replies directly into the list.
4. **Keep URL-driven filters out of Vue-owned shadow query state.**
   If a route's URL changes list filters, pagination, or search, derive Source Input from `Alva.LiveView.route_params(socket)` and let Alva refresh the Collection server-side. Do **not** mirror that route state into `ashQuery`, local `ref([])`, or another client-owned list cache just to re-fetch a route-owned Collection.
5. **Use Signals for Everything Else.**
   If you just need a pub/sub trigger for a semantic effect (like a toast notification, or re-running a non-collection chart computation), use a `signal` projection.
