Status: ready-for-agent

## Parent
.scratch/alva-v2-streams/PRD.md

## What to build
Implement the end-to-end lifecycle for Paradigm B (Dynamic Client Signals). 
1. Add the `signal` DSL (with `name`, `on`, `authorize_with`) to Ash Resource declaration parsing.
2. Intercept the `alva:subscribe_signal` payload in `Alva.LiveView`, map arguments directly to the Ash `authorize_with` action for security, and execute `Phoenix.PubSub.subscribe`.
3. Build the `ash.on` hook in the Alva Vue Client, ensuring it auto-cleans up via `onUnmounted` by emitting `alva:unsubscribe_signal`.
4. Ensure all relevant existing tests for signaling are updated, and properly clean up/remove any outdated tests related to this specific path.

## Acceptance criteria
- [ ] `signal` block successfully parses in Ash Resource.
- [ ] `ash.on` in Vue requests a subscription with payload.
- [ ] LiveView authorizes the subscription using Ash Policy before calling `Phoenix.PubSub.subscribe`.
- [ ] `onUnmounted` properly issues an unsubscribe event to LiveView.
- [ ] Old tests for these signal paths are cleaned up and new tests verify security boundaries (Seam 5).

## Blocked by
None - can start immediately
