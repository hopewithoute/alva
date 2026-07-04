# Alva Realtime Model (Phase 9)

## Overview

Based on ADR 0002 and ADR 0003, Alva's realtime communication model separates concerns into **Commands**, **Route Subscriptions**, **Collections**, **Route Collections**, **Stream Queries**, **Signals**, **Resource Projections**, and **Page Projections**.

This separation explicitly maps resource-level definitions to page-level (route-level) activations, keeping collection synchronization cleanly on the server (via Phoenix stream operations and LiveVue diffs) while preserving semantic signals and ad hoc commands for the client.

### Vocabulary

* **Command**: A Vue-to-server request/reply interaction (e.g., `ash.ashCall('students.create', {...})`). It provides immediate, normalized feedback to the caller but does not directly broadcast realtime state changes to other clients.
* **Route Subscription**: A page-level declaration indicating which PubSub topics a given LiveView page cares about (e.g., `Alva.LiveView.subscribe(socket, "students:all")`).
* **Collection**: A server-owned reactive list defined in an Ash Resource's `live_vue` block. It must declare an explicit source event for initial/reset data and may map Ash PubSub published event names (via `on:`) to Phoenix LiveStream operations that LiveVue delivers as stream diffs. A Collection with no insert/update/delete mappings is source-only and should produce a warning.
* **Stream**: The internal Phoenix LiveStream/LiveVue stream-diff transport used for Collections. It is not the public DSL name.
* **Route Collection**: A collection of data initialized and maintained server-side (often pushed via `stream(:students, data)`) and synchronized out to the subscribed route's LiveVue instances automatically.
* **Stream Query**: A page-level binding that takes a paginated or filtered command result and applies it to an active stream server-side.
* **Signal**: A semantic, non-collection callback event delivered to Vue via `ash.on('event', payload)` (e.g., toast notifications, generic broadcast triggers).
* **Resource Projection**: The foundational block inside an Ash Resource (the Collection Block or Subscribe Block) dictating what happens when an Ash PubSub event fires.
* **Page Projection**: The active realization of a resource projection on a specific route, instantiated via `Alva.LiveView.collection/2` or `activate_signal/2`.

---

## Defining Resource Projections

Define collections and signals within the `live_vue` block of your Ash Resource. Note that the `on:` mappings must strictly match **Ash PubSub published event names** (configured in the `pub_sub` block):

```elixir
defmodule MyApp.Academics.Student do
  use Ash.Resource, extensions: [Alva.Resource, Ash.Notifier.PubSub]
  
  pub_sub do
    module MyAppWeb.Endpoint
    prefix "students"
    publish :create, ["all"], event: "student_created"
    publish :archive, ["all"], event: "student_archived"
  end

  live_vue do
    # Collection Block (Resource Projection)
    collection :students do
      source event: "students.list", mode: :reset
      insert on: "student_created", at: 0, limit: -20
      update on: "student_archived", update_only: true
      delete on: "student_deleted"
    end

    # Subscribe Block (Resource Projection)
    signal "students.created", on: "student_created"
  end
end
```

---

## Activating Page Projections & Route Subscriptions

On your LiveView (the page level), hook into `Alva.LiveView` to subscribe to the PubSub topics and activate only the projections you need for that route. Simple pages may use the `collections: [...]` allowlist; advanced pages may activate Collections in `mount`.

```elixir
defmodule MyAppWeb.HomeLive do
  use MyAppWeb, :live_view
  use Alva.LiveView,
    domains: [MyApp.Academics],
    collections: [
      students: [params: %{status: "active"}]
    ],
    subscriptions: ["students:all"]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      # Advanced pages can activate manually instead of using collections: [...]
      # |> Alva.LiveView.collection(:students, params: %{status: "active"})
      # |> Alva.LiveView.subscribe("students:all")
      |> Alva.LiveView.activate_signal("students.created")

    {:ok, socket}
  end
end
```

No Collection or PubSub subscription is activated merely because its domain is mounted. The `collections: [...]` and `subscriptions: [...]` options are declarative shortcuts for simple pages; advanced pages may still call `Alva.LiveView.collection/2` and `Alva.LiveView.subscribe/2` in `mount`. The render boundary remains explicit: Vue receives `@streams.collection_name` as a prop.

Collection activation supports source parameters from the start. If no params are provided, Alva dispatches the Collection source with `%{}`. Simple pages may use static params in `collections: [...]`; advanced pages may use local callback names for DB-backed or route-dependent params and topics. Manual helpers remain available for conditional activation, route-state changes, custom subscription lifecycles, and complex multi-step setup.

Activation callbacks may return a raw value or `{:ok, value}`. Returning `{:error, reason}` raises an activation error because declarative activation is a fail-loud page setup path, not user-facing validation. If a route needs graceful 404, redirect, or conditional behavior, use manual `mount` branching before activating the Collection.

Collection sources do not declare result shape. Alva uses the source event's Auto-DTO/projection contract as the source of truth for the records to stream. Standard resource lists and supported Ash page-like results stream their records automatically; custom DTO envelopes used as Collection sources must make their record field clear in the DTO/projection layer. If Alva cannot determine records, Collection activation fails with an actionable message naming the collection and source event.

Collections lean on Phoenix LiveView stream semantics instead of reimplementing list reconciliation. Identity is handled by LiveView `dom_id`, defaulting to `item.id`; custom DTO projections may use stream configuration if they need a custom DOM identity. Duplicate handling is handled by `stream_insert` plus LiveVue upsert, so the caller's immediate command update and the later PubSub echo do not create duplicate DOM records.

Insert operations must declare `at:` explicitly and use Phoenix LiveView stream index semantics directly: `at: 0` inserts at the beginning, `at: -1` appends at the end, and other integers are passed through to LiveView. Alva does not infer insert position from source data ordering; sorted or filtered Collections that cannot safely accept positional inserts should use a source refresh operation instead.

Update operations map to `stream_insert(..., update_only: true)` by default, which updates existing items without inserting missing items. If a Collection intentionally wants an update occurrence to insert missing items, it can opt into the native LiveView behavior with `update_only: false` and provide any needed `at:`/`limit:` options directly.

---

## Vue Frontend Implementation

Because LiveVue stream diffs automatically synchronize the Collection prop, the Vue component no longer manually pushes or splices arrays for route-owned collections:

```vue
<template>
  <div>
    <!-- Triggering a Stream Query behavior without a local load-more DSL -->
    <button @click="refresh_list">Refresh Students</button>
  </div>
</template>

<script setup lang="ts">
import { useAlvaApi } from 'alva'

// The Collection prop is managed by the server through LiveVue stream diffs.
const props = defineProps<{ students: Student[] }>()

const ash = useAlvaApi<AlvaEvents, SignalEvents>()

// Signal usage for a non-collection callback
ash.on('students.created', (payload) => {
  alert(`Toast: A new student was added: ${payload.data.name}`)
})

const create_student = async () => {
  // Command mutation provides immediate feedback
  const reply = await ash.ashCall('students.create', { name: "Bob" })
  
  if (reply.ok) {
    // DO NOT MANUALLY UPDATE props.students!
    // The server handles the Route Collection via Phoenix LiveStream + LiveVue.
  }
}

const refresh_list = async () => {
  // Calls the server; the result is applied to the active Collection server-side.
  await ash.ashCall('students.list', {})
}
</script>
```

---

## Migration Notes (Upgrading to Phase 9)

When migrating older components to the Phase 9 architecture, observe the following rules:

1. **Stop using `ashQuery` stream reconciliation.**
   Route-owned collections must use Phoenix stream operations plus LiveVue stream diffs. Do **not** use `ashQuery` stream insert/delete callback reconciliation. The `updateArray` logic and stream callbacks in `ashQuery` have been completely removed.
2. **Move Collection State to Props.**
   Instead of holding an array in `ref<Student[]>([])` and querying it `onMounted`, declare a `defineProps<{ students: Student[] }>()` and let LiveVue supply the stream data initialized by the LiveView.
   In the LiveView render, pass the server-owned stream explicitly:

   ```elixir
   <.vue v-component="StudentsPage" students={@streams.students} />
   ```

   Remove temporary `v-diff={false}` workarounds and plain list assigns such as `assign(:students, ...)` once the route-owned list is an Alva Collection. Plain assigns are still fine for non-Collection props.
3. **Use Explicit Collection Sources.**
   Every Collection must declare its initial load/reset path with `source event: ...`. If you need refresh, pagination, or filtering, route that command result through the explicit source and let Alva apply it natively to the active server-owned Collection.
4. **Use Signals for Everything Else.**
   If you just need a pub/sub trigger for a semantic effect (like a toast notification, or re-running a non-collection chart computation), use a `signal` projection.
