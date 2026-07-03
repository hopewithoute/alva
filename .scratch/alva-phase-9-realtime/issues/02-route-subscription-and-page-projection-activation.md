Status: ready-for-agent

# Route Subscription and Page Projection Activation

## Parent

.scratch/alva-phase-9-realtime/PRD.md

## What to build

Add the page-level activation model for Phase 9. A LiveView page should be able to declare which concrete Route Subscriptions it listens to and which Resource Projections are active on that page. Raw Phoenix PubSub subscription must remain valid, while Alva should provide a thin helper for consistent examples and future introspection.

The same Resource Projection should remain inactive unless the page explicitly activates it. This preserves the page-scoped model where the same server occurrence may be streamed on one page, signaled on another, and ignored elsewhere.

## Acceptance criteria

- [ ] A LiveView page can use a thin Alva helper to subscribe to a concrete PubSub topic.
- [ ] Raw Phoenix PubSub subscription remains compatible with Alva projection handling.
- [ ] A LiveView page can activate a Stream projection by its domain-unique stream name.
- [ ] A LiveView page can activate a Signal projection by its domain-unique signal name.
- [ ] Inactive projections do not handle incoming notifications.
- [ ] Activation state is scoped to the LiveView socket/page, not global.
- [ ] Tests cover activating different projections for the same incoming occurrence on different pages.

## Blocked by

- .scratch/alva-phase-9-realtime/issues/01-dsl-contract-for-stream-and-signal-projections.md

