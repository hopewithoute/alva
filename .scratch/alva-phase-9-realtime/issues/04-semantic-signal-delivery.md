Status: ready-for-agent

# Semantic Signal Delivery

## Parent

.scratch/alva-phase-9-realtime/PRD.md

## What to build

Route incoming Ash PubSub notifications through active Signal projections and push semantic callback events to Vue. Signals are for non-collection cases such as async job progress, completion, presence, typing indicators, and UI notifications.

The final Signal contract must not expose every notification as a generic `ash_notification` envelope. Vue should receive the semantic signal name and projected payload for active Signals only.

## Acceptance criteria

- [ ] An incoming notification matching an active Signal projection pushes the semantic signal name to Vue.
- [ ] Signal payloads use the established Projection Rule and do not expose raw Ash resource internals.
- [ ] Notifications for inactive Signal projections are ignored by that page.
- [ ] The same published occurrence can be used as both a Stream and a Signal when a page activates both.
- [ ] The existing generic `ash_notification` behavior is replaced or quarantined so it is not the public Signal contract.
- [ ] Tests cover async/non-collection Signal delivery without mutating a Route Collection.

## Blocked by

- .scratch/alva-phase-9-realtime/issues/01-dsl-contract-for-stream-and-signal-projections.md
- .scratch/alva-phase-9-realtime/issues/02-route-subscription-and-page-projection-activation.md

