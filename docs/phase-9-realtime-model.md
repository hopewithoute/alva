# Alva Realtime Model (Phase 9)

## Overview

Based on ADR 0002, Alva's realtime communication model separates concerns into **Commands**, **Route Subscriptions**, **Streams**, **Route Collections**, **Stream Queries**, and **Signals**. 

This separation explicitly maps resource-level definitions to page-level (route-level) activations, keeping collection synchronization cleanly on the server (via Phoenix stream operations and LiveVue diffs) while preserving semantic signals and ad hoc commands for the client.

### Vocabulary

* **Command**: A Vue-to-server request/reply interaction (e.g., `api.ashCall('students.create', {...})`). It provides immediate, normalized feedback to the caller but does not directly broadcast realtime state changes to other clients.
* **Route Subscription**: A page-level declaration indicating which PubSub topics a given LiveView page cares about (e.g., `Alva.LiveView.subscribe(socket, "students:all")`).
* **Stream**: A server-side collection projection defined in an Ash Resource's `live_vue` block. It maps Ash PubSub published event names (via `on:`) to LiveVue stream operations (`insert`, `update`, `delete`).
* **Route Collection**: A collection of data initialized and maintained server-side (often pushed via `stream(:students, data)`) and synchronized out to the subscribed route's LiveVue instances automatically.
* **Stream Query**: A page-level binding that takes a paginated or filtered command result and applies it to an active stream server-side.
* **Signal**: A semantic, non-collection callback event delivered to Vue via `api.on('event', payload)` (e.g., toast notifications, generic broadcast triggers).
* **Resource Projection**: The foundational block inside an Ash Resource (the Stream Block or Signal Block) dictating what happens when an Ash PubSub event fires.
* **Page Projection**: The active realization of a resource projection on a specific route, instantiated via `Alva.LiveView.activate_stream/2` or `activate_signal/2`.

---

## Defining Resource Projections

Define streams and signals within the `live_vue` block of your Ash Resource. Note that the `on:` mappings must strictly match **Ash PubSub published event names** (configured in the `pub_sub` block):

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
    # Stream Block (Resource Projection)
    stream :students do
      insert on: "student_created"
      update on: "student_archived"
    end

    # Signal Block (Resource Projection)
    signal "students.created", on: "student_created"
  end
end
```

---

## Activating Page Projections & Route Subscriptions

On your LiveView (the page level), hook into `Alva.LiveView` to subscribe to the PubSub topics and explicitly activate the projections you need for that route:

```elixir
defmodule MyAppWeb.HomeLive do
  use MyAppWeb, :live_view
  use Alva.LiveView, domains: [MyApp.Academics]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # 1. Route Subscription
      Alva.LiveView.subscribe(socket, "students:all")
    end

    # 2. Initial Route Collection Load
    %{ok: true, data: students} = Alva.Dispatcher.dispatch("students.list", %{}, domains: [MyApp.Academics])

    socket =
      socket
      # 3. Activate Page Projections
      |> Alva.LiveView.activate_stream(:students)
      |> Alva.LiveView.activate_signal("students.created")
      # 4. Bind Stream Query for Pagination/Refresh (mode: :reset, :append, :prepend)
      |> Alva.LiveView.bind_stream_query("students.list", :students, mode: :reset)
      |> stream(:students, students)

    {:ok, socket}
  end
end
```

---

## Vue Frontend Implementation

Because LiveVue stream diffs automatically synchronize the stream prop, the Vue component no longer manually pushes or splices arrays for route-owned collections:

```vue
<script setup lang="ts">
import { useAlvaApi } from 'alva'

// The Stream Prop is managed by LiveVue
const props = defineProps<{ students: Student[] }>()

const api = useAlvaApi<AlvaEvents, SignalEvents>()

// Signal usage for a non-collection callback
api.on('students.created', (payload) => {
  alert(`Toast: A new student was added: ${payload.data.name}`)
})

const createStudent = async () => {
  // Command mutation provides immediate feedback
  const reply = await api.ashCall('students.create', { name: "Bob" })
  
  if (reply.ok) {
    // DO NOT MANUALLY UPDATE props.students!
    // The server handles the Route Collection via Phoenix Streams + LiveVue.
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
   Instead of holding an array in `ref<Student[]>([])` and querying it `onMounted`, declare a `defineProps<{ students: Student[] }>()` and let LiveVue supply the stream data initialized by the LiveView.
3. **Use Page-Level Stream Queries.**
   If you need to paginate or filter, do not build resource-level load-more DSLs. Instead, rely on `Alva.LiveView.bind_stream_query/4` to apply paginated command results natively to an active stream server-side.
4. **Use Signals for Everything Else.**
   If you just need a pub/sub trigger for a semantic effect (like a toast notification, or re-running a non-collection chart computation), use a `signal` projection.
