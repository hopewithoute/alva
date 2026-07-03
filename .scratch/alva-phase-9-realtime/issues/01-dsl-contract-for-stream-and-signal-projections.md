Status: done

# DSL Contract for Stream and Signal Projections

## Parent

.scratch/alva-phase-9-realtime/PRD.md

## What to build

Add the resource-level contract for Phase 9 Resource Projections. Developers should be able to declare domain-unique Stream Blocks with explicit insert/update/delete `on:` mappings and domain-unique Signals for semantic non-collection callbacks. These declarations must be discoverable through Info helpers and persisted at the domain level separately from existing command events.

This slice should keep command `event` declarations distinct from Stream/Signal projection triggers. `on:` references Ash PubSub published event names and must not be confused with Alva command events.

## Acceptance criteria

- [x] A resource can declare a Stream Block with insert/update/delete `on:` mappings.
- [x] A resource can declare a Signal with an `on:` mapping.
- [x] Resource Info helpers expose command events, stream projections, and signal projections separately.
- [x] Domain Info helpers expose separate command, stream, and signal lookup maps.
- [x] Duplicate command event names still fail at domain compile time.
- [x] Duplicate stream names fail at domain compile time.
- [x] Duplicate signal names fail at domain compile time.
- [x] Stream and Signal projection trigger names are structurally validated as Ash PubSub published event references.

## Blocked by

None - can start immediately
