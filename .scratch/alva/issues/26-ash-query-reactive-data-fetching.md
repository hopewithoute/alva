# 26 - ashQuery (Reactive Data Fetching & Streams)

Status: done

## Parent
`.scratch/alva/PRD.md` (Phase 6)

## What to build
A Vue composable `ashQuery` used for fetching list data and acting as a reactive accumulator. It will fetch initial state via `ashCall` and automatically subscribe to LiveView stream events (`stream_insert`, `stream_delete`) via `ash.on` to update the local reactive array automatically.

## Acceptance criteria
- [ ] Implement `ashQuery` that fetches data on mount (if no initial data is provided).
- [ ] Automatically subscribes to stream events and updates the reactive array state.
- [ ] Exposes loading, error, and data states cleanly to the Vue template.

## Blocked by
- Issue 24 (`ashCall`)
- Issue 25 (`ash.on`)
