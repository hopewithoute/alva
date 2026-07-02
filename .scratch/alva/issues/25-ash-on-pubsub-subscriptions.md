# 25 - ash.on (PubSub Subscriptions)

Status: done

## Parent
`.scratch/alva/PRD.md` (Phase 6)

## What to build
A strongly-typed Vue listener for real-time events pushed from the server. This listens to LiveView's `push_event` payloads and provides a clean callback mechanism for Vue components to react. This forms the foundation for reactive list streams and notification feeds.

## Acceptance criteria
- [ ] Implement `ash.on` (or equivalent inside `useAlvaApi`) to listen to specific server-pushed events.
- [ ] Callbacks receive fully typed payloads.
- [ ] Ensures listeners are cleaned up properly when the Vue component unmounts to prevent memory leaks.

## Blocked by
None - can start immediately
