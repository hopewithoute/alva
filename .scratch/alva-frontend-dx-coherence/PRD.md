Status: draft

# PRD — Alva Bridge-First Surface v2

## Context

Alva started as an Ash-to-Vue bridge over LiveView and LiveVue. The original
promise was simple:

1. Expose Ash actions to Vue without building a separate REST/tRPC layer.
2. Preserve cross-page and cross-window reactivity through LiveView and Ash
   PubSub.
3. Keep Vue as the view runtime, not the domain authority.

The current public surface has drifted beyond that bridge-first goal. Route
Collections, `route_subscriptions:`, `page_events:`, `page_state:`, and
several custom Vue composables now form a page-owned runtime on top of
LiveView. That runtime is powerful, but it also overlaps with capabilities that
LiveVue already provides:

- reactive props driven by LiveView assigns
- native Phoenix `stream/3` synchronization into Vue props
- `useLiveVue()` and `useLiveEvent()`
- `useLiveNavigation()`
- `useLiveUpload()`
- `useLiveForm()`
- persistent layout and shared hook lookup patterns

This PRD proposes a surface reset. Alva v2 should lean on LiveVue for UI and
transport primitives, while Alva itself focuses on Ash-aware contracts,
typed commands, typed subscriptions, scope resolution, and PubSub-to-LiveView
projection.

## Problem Statement

The current Alva surface solves real problems, but it mixes two products into
one library:

1. **Bridge product**
   - typed command dispatch
   - actor/tenant injection
   - DTO generation
   - error normalization
   - Ash-aware uploads
   - generated frontend contracts

2. **Page runtime product**
   - declarative Collection activation
   - explicit route topic wiring
   - page-owned state callbacks
   - page-owned event callbacks
   - route lifecycle coordination

The bridge product is Alva's clearest unique value. The page runtime product is
where the library has become hardest to learn, hardest to document, and most
likely to duplicate LiveVue.

We need a v2 surface that:

- keeps typed Ash integration as the core value
- preserves granular realtime scope
- allows frontend-controlled activation without exposing raw PubSub topics
- reduces page-level DSL and callback surface dramatically
- leans on native LiveView + LiveVue primitives instead of reimplementing them

## Product Positioning

Alva v2 is an **Ash-aware bridge on top of LiveView + LiveVue**.

Alva v2 is **not**:

- a generic client-side state manager
- a replacement for LiveVue form, upload, navigation, or connection primitives
- a general-purpose page runtime layered above LiveView
- a browser-owned subscription transport

Alva v2 **does** own:

- typed Ash command contracts
- typed realtime subscription contracts
- global host-app registry for commands and subscriptions
- scope resolution from public subscription input to concrete server scope
- mapping Ash PubSub notifications into LiveView stream ops or browser events
- codegen for DTOs, commands, and subscriptions

## Goals

1. Keep commands first-class and typed through `useAlvaApi`.
2. Replace page-owned Collection/Signal activation with **typed subscription
   capabilities** generated from backend definitions.
3. Keep realtime transport server-owned: LiveView subscribes to PubSub, Vue
   does not subscribe to raw transport topics directly.
4. Allow frontend pages and components to activate and deactivate subscriptions
   granularly through typed SDK calls.
5. Preserve multi-window and multi-route synchronization through Ash PubSub.
6. Reuse LiveVue native props and `@streams.*` as the rendering model for
   route-owned live lists.
7. Reduce or remove public surfaces that duplicate LiveVue functionality.
8. Keep route/tenant/actor-aware scope resolution on the server.

## Non-Goals

1. Replacing LiveView's native `stream/3` model.
2. Replacing LiveVue's client API surface.
3. Exposing raw PubSub topic strings to Vue as public API.
4. Turning ad hoc request/reply queries into implicit long-lived subscriptions.
5. Building a GraphQL-like dynamic subscription or field selection layer.
6. Preserving the current `collections:` / `route_subscriptions:` /
   `page_events:` / `page_state:` page DSL as the primary learning path.

## Core Design

### 1. Commands stay explicit

Commands remain request/reply operations exposed from Ash resources.

```elixir
live_vue do
  event :create_order,
    name: "orders.create",
    action: :create
end
```

Vue keeps using a typed command bridge:

```ts
const api = useAlvaApi<AlvaEvents>()
const result = await api.call("orders.create", { reference: "SO-1001" })
```

### 2. Realtime moves to typed subscription capabilities

Instead of page-owned Collection and Signal activation surfaces, backend code
defines **subscription capabilities** globally.

Each capability has:

- an exposed name
- a kind (`stream` or `signal`)
- a public input schema
- optional source event information for stream snapshot loading
- one or more PubSub occurrence triggers
- a server-side scope resolver

Example:

```elixir
live_vue do
  event :list_support_messages,
    name: "support_messages.list",
    action: :read

  subscription :support_messages do
    name "support_messages"
    kind :stream

    source event: :list_support_messages

    scope %{
      conversation_id: :uuid
    }

    insert on: :create, at: -1
    update on: :update, update_only: true
    delete on: :delete

    resolve :resolve_support_messages_scope
  end

  subscription :order_fulfilled do
    name "order_fulfilled"
    kind :signal

    scope %{
      store_id: :uuid
    }

    on :fulfill
    resolve :resolve_order_fulfilled_scope
  end
end
```

### 3. Global topic map is backend-owned

The runtime keeps a **global host-app topic map** and subscription registry.

That registry is built from backend declarations and contains:

- command event map
- subscription capability map
- notification trigger map
- DTO/payload projection metadata
- upload argument metadata

Frontend never sees concrete topic strings as public API.

Frontend sees:

- command names
- subscription names
- typed subscription input
- typed payload or stream item shape

### 4. Frontend controls activation intent, not transport topics

Vue components and pages may activate a capability, but they do so by sending a
typed **activation intent**.

Good:

```ts
subs.activate("support_messages", { conversation_id })
subs.on("order_fulfilled", { store_id }, handler)
```

Bad:

```ts
subs.subscribe("support_message:conversation:123")
```

The backend remains authoritative for:

- resolving topic strings
- authorization
- tenant scoping
- deduping subscriptions per LiveView process
- deciding whether a capability is rendered as stream state or browser event

### 5. Scope resolution is a first-class server contract

Scope resolution takes:

- public activation input from Vue
- server context from the LiveView socket
- resource/subscription declaration metadata

And returns:

- a stable subscription key
- concrete PubSub topics
- `source_input` for stream snapshot loading, when needed

Resolver return contract:

```elixir
{:ok,
 %{
   key: {:support_messages, tenant_id, conversation_id},
   topics: ["support_message:conversation:#{conversation_id}"],
   source_input: %{"conversation_id" => conversation_id}
 }}
```

Allowed failures:

```elixir
{:error, :forbidden}
{:error, :not_found}
{:error, {:invalid_scope, errors}}
```

This consolidates concerns that are currently split across:

- `source_input:` callbacks
- `route_subscriptions:` callbacks
- route-param-aware page state callbacks

### 6. Stream subscriptions use native LiveView and LiveVue rendering

For `kind: :stream`, the backend still owns the route state.

The rendering contract stays native:

```elixir
<.vue
  v-component="CustomerStorefrontPage"
  support_messages={@streams.support_messages}
/>
```

LiveVue remains responsible for keeping that prop reactive as LiveView stream
operations run.

Alva is responsible for:

- initial snapshot load from `source event`
- subscription activation and deactivation
- mapping matching notifications into `stream_insert`, `stream_delete`, and
  `stream_insert(update_only: true)`

### 7. Signal subscriptions use native LiveVue browser events

For `kind: :signal`, matching server notifications are delivered through
`Phoenix.LiveView.push_event/3`, and Vue listens through `useLiveEvent()` or a
thin typed Alva wrapper.

## Proposed Public Surface

### Backend Surface

#### Keep

- `event`
- `subscription`
- DTO/codegen contracts
- dispatcher and upload bridge

#### Remove or Demote

- `collections:` as primary page DSL
- `signals:` as page activation DSL
- `route_subscriptions:`
- `page_events:`
- `page_state:`

These may remain temporarily as compatibility or escape hatch surfaces, but
they are no longer the primary documented API.

### LiveView Page Surface

Pages should expose a minimal **allowlist** of activatable capabilities instead
of owning full subscription wiring.

Draft shape:

```elixir
use Alva.LiveView,
  subscriptions: [
    :support_messages,
    :order_fulfilled
  ]
```

This means:

- the page allows those capabilities to be activated by the frontend
- transport topics still come from server-side scope resolution
- the page does not need route topic callback definitions

Optional future extension:

```elixir
use Alva.LiveView,
  subscriptions: [
    support_messages: [activate: :mount],
    order_fulfilled: [activate: :client]
  ]
```

This would let route-owned primary lists SSR on mount while still allowing
other capabilities to activate lazily from Vue.

### Vue Surface

#### Keep

- `useAlvaApi`

#### Add

- `useAlvaStream`
- `useAlvaSignal`

*(Note: The low-level `useAlvaSubscriptions` engine is intentionally omitted from the public surface. It is an internal dependency used by the stream and signal composables to prevent manual lifecycle errors and memory leaks).*

#### Thin wrappers only

- `useAlvaUpload` over `useLiveUpload`
- `useAlvaForm` over `useLiveForm`

#### Remove or demote

- `useAlvaQuery`
- `useAlvaEvent`
- `provideAlvaPageState`
- `useAlvaPageState`

## TypeScript Codegen

Codegen should emit two primary contracts.

### Commands

```ts
export type AlvaEvents = {
  "orders.create": {
    input: {
      reference: string
    }
    output: AlvaResult<Order>
  }
}
```

### Subscriptions

```ts
export type AlvaSubscriptions = {
  support_messages: {
    kind: "stream"
    input: {
      conversation_id: string
    }
    item: SupportMessage
  }

  order_fulfilled: {
    kind: "signal"
    input: {
      store_id: string
    }
    payload: OrderFulfilled
  }
}
```

Generated client helpers may optionally expose ergonomic namespaces, but the
core contract should remain explicit and type-driven.

## Vue SDK Sketch

### Commands

```ts
const api = useAlvaApi<AlvaEvents>()
await api.call("orders.create", { reference: "SO-1001" })
```

### Signals

```ts
const subs = useAlvaSubscriptions<AlvaSubscriptions>()

subs.on("order_fulfilled", { store_id }, (payload) => {
  console.log(payload.reference)
})
```

### Streams

```ts
const messages = useAlvaStream<AlvaSubscriptions>("support_messages", {
  conversation_id,
})
```

`useAlvaStream(...)` should:

- activate the stream capability when mounted
- deactivate it when unmounted
- return reactive stream status only if needed
- not own the canonical list data in Vue

The canonical list still comes from the LiveView prop:

```ts
const props = defineProps<{
  support_messages: SupportMessage[]
}>()
```

## Runtime Flow

### Stream subscription activation

1. Vue calls `useAlvaStream("support_messages", { conversation_id })`.
2. The SDK sends an activation intent to the current LiveView.
3. LiveView checks whether `:support_messages` is allowed on this page.
4. LiveView validates the public input against the generated schema.
5. LiveView resolves scope using the subscription resolver and current socket
   context.
6. LiveView dedupes or ref-counts the resolved subscription key.
7. If this is the first active reference:
   - subscribe the LiveView process to the resolved topics
   - run the source event using resolved `source_input`
   - populate or reset the corresponding `@streams.support_messages`
8. Matching Ash PubSub notifications update the stream through native
   LiveView stream operations.
9. Unmount or explicit deactivate decrements the ref-count and unsubscribes
   when the last consumer is gone.

### Signal subscription activation

1. Vue calls `subs.on("order_fulfilled", { store_id }, handler)`.
2. The SDK sends an activation intent to LiveView.
3. LiveView validates allowlist and input.
4. LiveView resolves scope and subscribes transport topics if needed.
5. Matching notifications are pushed to Vue with `push_event`.
6. The SDK unregisters the handler and deactivates when the component unmounts.

## Why This Is Simpler

This design removes several public seams that currently force developers to
think in backend transport details:

- no page-owned `route_subscriptions:` callback contract
- no page-owned `source_input:` callback contract for the common case
- no page-owned `page_state:` callback contract
- no page-owned `page_events:` callback contract for standard command and
  navigation flows
- no public raw-topic mental model on the frontend

The new model has one central concept for realtime:

```text
typed subscription capability
```

That capability combines:

- what the frontend may ask for
- what the backend is allowed to subscribe to
- how the backend projects notifications into stream or signal updates

## Relationship To LiveVue

LiveVue should remain the first choice for generic client-side primitives:

- `useLiveVue()` for raw hook access
- `useLiveEvent()` for server-pushed browser events
- `useLiveNavigation()` for patch and navigate
- `useLiveUpload()` for upload UI
- `useLiveForm()` for server-driven forms
- `useEventReply()` for generic request/reply flows
- `useLiveConnection()` for connectivity state

Alva should only wrap these when Ash-specific semantics materially improve the
experience.

Examples:

- `useAlvaUpload` may stay to bridge uploaded refs into Ash file arguments.
- `useAlvaForm` may stay only if it becomes a thin Ash adapter over
  `useLiveForm`.
- `useAlvaQuery` should not survive as a first-class abstraction if
  `useEventReply` already covers the same request/reply ground.

## Compatibility And Migration

### Surfaces to deprecate

- `collections:`
- `signals:`
- `route_subscriptions:`
- `page_events:`
- `page_state:`
- `useAlvaQuery`
- `useAlvaEvent`
- `provideAlvaPageState`
- `useAlvaPageState`

### Surfaces to keep but narrow

- `useAlvaApi`
- `useAlvaUpload`
- `useAlvaForm`
- `Alva.LiveView`

### Migration path

1. Introduce `subscription` backend DSL and generated `AlvaSubscriptions`.
2. Add frontend activation SDK while keeping old page DSL working.
3. Move demo pages to typed subscription activation.
4. Rewrite docs to teach commands + subscriptions + native LiveVue streams.
5. Demote page runtime docs to compatibility/legacy sections.
6. Remove obsolete surfaces after migration confidence is high.

## Testing Decisions

- Codegen tests must cover subscription type generation for both `stream` and
  `signal` kinds.
- Resolver tests must cover valid scope resolution, forbidden access, not found,
  and invalid scope input.
- LiveView integration tests must cover:
  - activation allowlist enforcement
  - ref-counted subscribe/unsubscribe behavior
  - stream snapshot loading on activation
  - stream updates from matching notifications
  - signal delivery through `push_event`
  - cross-window synchronization through Ash PubSub
- Frontend tests must cover:
  - typed activation input
  - automatic cleanup on unmount
  - dedupe behavior when two components activate the same capability
  - thin wrapper behavior over LiveVue primitives

## Resolved Decisions (from Architecture Grilling)

1. **Eager vs. Lazy Activation (Q1 & Q4):** A stream capability must support both. Eager activation (`activate: :mount`) is mandatory for primary lists to preserve full SSR. Lazy client activation is strictly for secondary/deferred UI (e.g., off-canvas modals).
2. **Terminology (Q2):** The public name for the realtime capability remains `subscription` (specifically, `kind: :stream` and `kind: :signal`), as it aligns best with the frontend mental model.
3. **Signal Wrapper (Q3):** `useAlvaSignal` is adopted as the primary, official API for Vue components. Relying solely on `subs.on(...)` is discouraged in components to prevent memory leaks from forgotten `onUnmounted` cleanups.
4. **Allowlist Declaration (Q5):** Page allowlists are declared in `use Alva.LiveView, subscriptions: [...]` to maintain clear backend authority and explicit module-level behavior.
5. **Data Delivery Boundary:** We strictly separate Lifecycle from Data Delivery. Streams deliver data **only** via Vue props powered by LiveVue. `useAlvaStream` only signals intent and manages lifecycle; it does not return data. Client-side "Live Queries" are explicitly banned. (Documented in ADR 0009).
6. **Pagination (Load More):** To support infinite scrolling without destroying the subscription, `useAlvaStream` returns a controller object containing a `loadMore(params)` function. This tells the backend to fetch and `stream_insert` the next page of data while keeping the existing PubSub connection intact.
7. **Stream Error Handling:** To properly surface scope resolution failures (e.g., `{:error, :forbidden}`), `useAlvaStream` must return reactive metadata refs (`isLoading`, `error`). The backend pushes rejection reasons back to the calling composable, allowing Vue to render appropriate fallback UI even when the data `props` remain empty.
8. **Canonical Stream Updates (Q6):** We rely exclusively on PubSub fan-out to update streams. Server-side optimistic projection after command success is removed to prevent race conditions and enforce a single, predictable path for data entry (the PubSub `handle_info` listener). Any optimistic UI needs are strictly client-side concerns.
9. **Vue Surface Safety:** The raw `useAlvaSubscriptions` engine is demoted to an internal API. The public surface strictly exposes `useAlvaStream` and `useAlvaSignal` to enforce automatic `onUnmounted` cleanup and eliminate memory leaks.

## Success Criteria

This v2 direction is successful when:

1. New users can explain Alva in one sentence:
   "Alva gives Ash-backed typed commands and typed subscriptions to LiveVue."
2. A route-owned realtime list can be built without learning page-owned
   `route_subscriptions:` and `page_state:` callback contracts.
3. Cross-window updates still work through Ash PubSub and LiveView streams.
4. Frontend code activates typed capabilities without seeing raw topic strings.
5. The default documentation path leans on LiveVue rather than re-teaching a
   parallel client runtime.
