Status: done
Track: core-v2
PRD sequence: Migration step 2 - add typed stream activation on top of the backend registry

## PRD alignment

This is primary v2 work. Runtime hooks for typed stream activation now exist,
but the showcase still relies mostly on legacy `collection` projections instead
of true subscription-backed stream capabilities. This issue finishes the stream
half of the new model, including SSR-friendly eager activation and the ADR 0009
boundary where `useAlvaStream` owns lifecycle intent but not canonical data.

## What to build

Complete the end-to-end flow for `kind: :stream` on the backend-owned
subscription model. Add real subscription declarations for the primary list
resources used by the showcase, support eager streams (`activate: :mount`) via
native `Phoenix.LiveView.stream/3` without loading flicker, and prove lazy
activation plus `loadMore(...)` against actual subscription-backed resources.
`useAlvaStream` must continue to manage lifecycle only while canonical data
arrives through LiveVue props.

## Acceptance criteria

- [x] Primary showcase list resources expose `subscription ... kind :stream` declarations and appear in generated `AlvaSubscriptions`.
- [x] Eager streams configured with `activate: :mount` are populated during `mount`.
- [x] Lazy streams execute the `source event` when `useAlvaStream` sends the activation intent.
- [x] `useAlvaStream` does not become a client-owned data store; canonical list data still comes from LiveView props / `@streams.*`, and `loadMore(...)` works end-to-end against the subscription-backed stream.

## Blocked by

- None - foundation/runtime hook exists; this is the remaining stream proof slice
