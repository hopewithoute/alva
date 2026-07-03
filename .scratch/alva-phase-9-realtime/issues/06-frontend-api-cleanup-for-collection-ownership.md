Status: done

# Frontend API Cleanup for Collection Ownership

## Parent

.scratch/alva-phase-9-realtime/PRD.md

## What to build

Update the frontend API so route-owned collections are not maintained through Vue-side stream insert/delete callbacks. `ashQuery` should remain for ad hoc command/read fetching that is not owned by a route stream. `ash.on` should be positioned for Signals, not canonical collection reconciliation.

This slice should remove, replace, or clearly deprecate the old mental model where `ashQuery` owns `streamInsertEvent` and `streamDeleteEvent` reconciliation for route-owned collections.

## Acceptance criteria

- [x] `ashQuery` no longer presents route-owned collection reconciliation as its primary stream behavior.
- [x] Vue-side insert/delete/dedupe logic is removed or deprecated for Route Collections.
- [x] Signal callback usage through `ash.on` remains supported.
- [x] Type names and docs distinguish command/read fetching from Route Collection stream props.
- [x] Frontend tests verify ad hoc query behavior without stream insert/delete callback ownership.
- [x] Frontend tests verify Signal callback registration and cleanup.

## Blocked by

- .scratch/alva-phase-9-realtime/issues/03-pubsub-notification-to-active-route-collection.md
- .scratch/alva-phase-9-realtime/issues/04-semantic-signal-delivery.md
- .scratch/alva-phase-9-realtime/issues/05-stream-query-binding-for-pagination-and-refresh.md

