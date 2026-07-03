Status: done

# Phase 9 Documentation and Migration Notes

## Parent

.scratch/alva-phase-9-realtime/PRD.md

## What to build

Document the Phase 9 realtime model and migration path. The docs should explain Commands, Route Subscriptions, Streams, Route Collections, Stream Queries, Signals, Resource Projections, and Page Projections using the glossary vocabulary and ADR 0002.

The migration notes should call out that route-owned collections should use Phoenix stream operations plus LiveVue stream diffs, not `ashQuery` stream insert/delete callback reconciliation.

## Acceptance criteria

- [x] Documentation explains the Command, Stream, Signal, Route Subscription, and Page Projection split.
- [x] Documentation shows a Stream Block with `on:` mappings for Ash PubSub published event names.
- [x] Documentation shows page-level Route Subscription and projection activation.
- [x] Documentation shows Stream Query pagination/refresh behavior without resource-level load-more DSL.
- [x] Documentation shows Signal usage for a non-collection callback.
- [x] Migration notes explain how the old `ashQuery` streamInsert/streamDelete pattern is replaced for Route Collections.
- [x] Documentation references ADR 0002 or mirrors its decision clearly.

## Blocked by

- .scratch/alva-phase-9-realtime/issues/06-frontend-api-cleanup-for-collection-ownership.md
- .scratch/alva-phase-9-realtime/issues/07-end-to-end-realtime-demo.md

