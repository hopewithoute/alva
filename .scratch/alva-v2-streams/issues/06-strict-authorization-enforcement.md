Status: ready-for-agent

## Parent
.scratch/alva-v2-streams/PRD.md

## What to build
Enforce strict authorization defaults across LiveView PubSub subscriptions. The current implementation in `Alva.LiveView.handle_subscribe_signal` handles omitted `authorize_with` policies by defaulting to `true`, which bypasses Ash's strict consent requirement. This must be fixed to ensure no `Phoenix.PubSub.subscribe` occurs without explicit consent from the framework's authorization layer.

## Acceptance criteria
- [ ] Omitted `authorize_with` policies in `handle_subscribe_signal` correctly fail or strictly deny access instead of defaulting to `true`.
- [ ] Subscriptions cannot be established without explicit Ash policy consent.

## Blocked by
None - can start immediately.
