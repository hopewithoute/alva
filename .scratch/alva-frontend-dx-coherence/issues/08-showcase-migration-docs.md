Status: done
Track: core-v2
PRD sequence: Migration steps 3-5 - move demos, rewrite docs, and demote legacy runtime docs

## PRD alignment

This is the final user-facing migration issue for the PRD. It should complete
the move from the legacy page-owned runtime to the bridge-first command and
subscription path, then rewrite docs so legacy surfaces live only in
compatibility or migration notes.

## What to build

Finish migrating the demonstration pages in the showcase/sample app to the new
v2 architecture. Replace the primary `collections:` / `route_subscriptions:`
learning path with real subscription-backed `useAlvaStream` and
`useAlvaSignal`, and rewrite the public documentation to teach the bridge-first
surface accurately. Legacy `page_events:` / `page_state:` material should move
to compatibility or migration sections instead of staying on the main path.

## Acceptance criteria

- [x] Customer Storefront and Merchant Console no longer rely on `page_events:` / `page_state:` as the primary teaching path.
- [x] Demo app works end-to-end on subscription-backed V2 architecture.
- [x] Documentation thoroughly reflects the V2 PRD and ADR 0009, especially the lifecycle-vs-data boundary for streams.
- [x] Legacy page-runtime docs are demoted to compatibility or migration guidance instead of the primary learning path.

## Blocked by

- None - signal and stream pipelines are now proven, so this slice can finish the user-facing migration path
