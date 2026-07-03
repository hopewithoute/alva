Status: ready-for-agent

# End-to-End Realtime Demo

## Parent

.scratch/alva-phase-9-realtime/PRD.md

## What to build

Update or add a demo that proves the Phase 9 communication model end to end. The demo should show command feedback, multi-window collection updates through the server stream path, a Stream Query pagination/refresh flow, and at least one non-collection Signal.

The demo should make the distinction visible: commands answer the caller, streams synchronize Route Collections, and Signals deliver semantic callbacks.

## Acceptance criteria

- [ ] A command mutation returns immediate normalized feedback to the caller.
- [ ] The same mutation updates a Route Collection in another subscribed window through the stream path.
- [ ] A Route Collection is initialized server-side and rendered through LiveVue stream support.
- [ ] A Stream Query applies a paginated or filtered command result to an active stream server-side.
- [ ] A Signal is delivered to Vue as a semantic callback event.
- [ ] The demo does not use Vue-side manual append/delete/dedupe logic for route-owned collections.
- [ ] The demo can be verified with targeted tests or a documented manual flow.

## Blocked by

- .scratch/alva-phase-9-realtime/issues/03-pubsub-notification-to-active-route-collection.md
- .scratch/alva-phase-9-realtime/issues/04-semantic-signal-delivery.md
- .scratch/alva-phase-9-realtime/issues/05-stream-query-binding-for-pagination-and-refresh.md
- .scratch/alva-phase-9-realtime/issues/06-frontend-api-cleanup-for-collection-ownership.md

