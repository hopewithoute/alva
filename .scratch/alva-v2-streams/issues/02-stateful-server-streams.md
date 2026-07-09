Status: done
## Parent
.scratch/alva-v2-streams/PRD.md

## What to build
Implement the end-to-end lifecycle for Paradigm A (Stateful Server Streams).
1. Add the `streams:` macro parsing to `Alva.LiveView`.
2. Implement the SSR injection flow on `mount` which uses `source` to read from Ash and applies `scope`.
3. Implement `handle_info` in `Alva.LiveView` to capture Ash.Notifier PubSub updates, validate them against the `source` filter, and push `stream_insert` or `stream_delete` to Vue.
4. Clean up any related legacy LiveView tests and replace them with robust testing for Stream lifecycle and PubSub diffing.

## Acceptance criteria
- [ ] `streams:` block successfully parses in `Alva.LiveView`.
- [ ] Initial mount properly queries the database and injects initial stream state to `socket.assigns.streams`.
- [ ] LiveView correctly interprets incoming PubSub notifications and issues diff commands to Vue.
- [ ] Legacy stream initialization tests are cleaned up and replaced with the new tests (Seam 2, Seam 3).

## Blocked by
None - can start immediately
