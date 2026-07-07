# 0009. Unified Stream Boundary and API in Alva v2

## Context

In Alva v2, we are shifting away from a page-owned runtime DSL (`collections:`, `route_subscriptions:`, `page_state:`, `page_events:`) back to a Bridge-First surface. During the design of this V2 surface, a fundamental ambiguity arose regarding how realtime data should flow into Vue components:

1. Should client-side queries (`useAlvaApi`) be allowed to automatically become reactive, GraphQL-style live queries?
2. How does a Vue developer fetch data for a stream if the API is lazy?
3. How do we preserve Server-Side Rendering (SSR) if Vue lazily activates a stream on mount?

## Decision

We are establishing a strict "Unified Stream Boundary" governed by State Ownership:

### 1. Data Delivery is Strictly Separated from Lifecycle Intent
- **Data Delivery** is 100% unidirectional from Server -> Vue via **Props**. The server projects occurrences into native LiveView streams (`@streams.*`), which LiveVue syncs to Vue props. A `Stream` capability will **never** return data directly to the client API caller.
- **Lifecycle Intent** is 100% Vue -> Server via the composable `useAlvaStream("name", input)`. Vue uses this only to declare that a component needs the stream and to pass arguments, not to receive the data payload.

### 2. Client-Side Live Queries are Banned
To maintain Alva's architectural integrity and leverage Phoenix's native speed, we explicitly forbid implicit "Live Query" wrappers. If a developer wants a realtime list, they must use the Stream/Props boundary. If they want to fetch ad-hoc scalar data into a client-side `ref` and make it reactive, they must manually use `useAlvaApi` (Transient Fetch) combined with `useAlvaSignal` (Manual Mutation).

### 3. Eager Activation (`activate: :mount`) is Mandatory for SSR
To preserve SSR—a primary benefit of LiveVue—streams cannot rely solely on lazy client activation. The backend declaration `use Alva.LiveView, subscriptions: [...]` must support an `activate: :mount` option. When eager, the server populates the stream during initial HTML render. When Vue mounts and calls `useAlvaStream`, the SDK acts as a hydrator/ref-counter rather than triggering a double-fetch. Lazy activation (`activate: :client`) is reserved for secondary widgets (e.g., hidden modals).

## Consequences

- **Pros:** Perfect SSR support, zero client-side diffing overhead, single source of truth (Server), and complete alignment with Phoenix's native `stream/3`.
- **Cons:** Vue developers must embrace `Props` for data passing (which may require `provide/inject` for deeply nested components) rather than relying on magical data-returning composables.
- **Supersedes:** This ADR formally supersedes and deprecates previous page-owned DSL ADRs, specifically **ADR 0003** (Collections Are Server-Owned) and **ADR 0005** (Page Activation Surfaces), as "Collection" terminology is retired in favor of "Stream" capabilities.
