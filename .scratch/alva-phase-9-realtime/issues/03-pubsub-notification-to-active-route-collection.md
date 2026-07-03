Status: ready-for-agent

# PubSub Notification to Active Route Collection

## Parent

.scratch/alva-phase-9-realtime/PRD.md

## What to build

Route incoming Ash PubSub notifications through active Stream projections and mutate the corresponding server-side Phoenix stream. A record created, updated, or deleted in one subscribed window should update the same Route Collection in every subscribed window through LiveView stream operations and LiveVue stream diffs.

Vue must not manually append, replace, delete, or dedupe records for stream-owned Route Collections. The server stream operation is the canonical collection mutation path.

## Acceptance criteria

- [ ] An incoming notification matching an active Stream insert mapping inserts into the configured Phoenix stream.
- [ ] An incoming notification matching an active Stream update mapping updates/re-inserts into the configured Phoenix stream.
- [ ] An incoming notification matching an active Stream delete mapping deletes from the configured Phoenix stream.
- [ ] Notifications for inactive Stream projections are ignored by that page.
- [ ] The command caller still receives immediate command feedback independently of stream propagation.
- [ ] Tests demonstrate that two subscribed pages can receive the same collection update through the stream path.
- [ ] No Vue-side list reconciliation is required for the route-owned collection.

## Blocked by

- .scratch/alva-phase-9-realtime/issues/01-dsl-contract-for-stream-and-signal-projections.md
- .scratch/alva-phase-9-realtime/issues/02-route-subscription-and-page-projection-activation.md

