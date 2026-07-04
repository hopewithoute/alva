Status: done

# Introduce Collection DSL as LiveView Stream Contract

## Parent

.scratch/alva-collection-liveview-streams/PRD.md

## What to build

Add `collection` as the resource-level contract for server-owned reactive lists. A resource should be able to declare a collection with an explicit source event and optional insert/update/delete occurrence mappings. The declaration must be discoverable through resource and domain info helpers and must preserve the distinction between command events, Collections, and Signals.

This slice should not implement the runtime stream behavior yet. It establishes the contract and validation surface that later runtime slices consume.

## Acceptance criteria

- [x] A resource can declare `collection :name do source event: "...", mode: :reset end`.
- [x] Collection source event is required; omitting it fails with an actionable compile-time error.
- [x] Source-only Collections compile but emit a warning that they will not update from PubSub.
- [x] Collection names are domain-unique and duplicate collection names fail at compile time.
- [x] Collection operation `on:` values remain Ash PubSub published event identities, not Alva command event names.
- [x] Resource and domain info helpers expose Collections separately from command events and Signals.
- [x] Existing stream/signal command tests continue to pass or have a documented compatibility migration path.

## Blocked by

None - can start immediately
