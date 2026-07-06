Status: ready-for-agent

# Support Dynamic Route Subscription Callback Semantics

## Parent

.scratch/alva-declarative-realtime-surface/PRD.md

## What to build

Support callback-derived `route_subscriptions:` values for dynamic Page Scope cases such as actor, tenant, route params, and permission checks. Callback results should have a strict return contract, with `[]` as the only authoritative opt-out and `nil` as an invalid return.

This slice should also normalize duplicate Topics and dedupe shared transport subscriptions while keeping projection semantics independent.

## Acceptance criteria

- [ ] A callback may return a binary Topic.
- [ ] A callback may return a list of binary Topics.
- [ ] A callback may return `[]` as an authoritative dynamic opt-out.
- [ ] A callback may return `{:ok, value}` wrapping any valid Topic return shape.
- [ ] A callback returning `nil` fails loudly.
- [ ] Duplicate Topics in one callback result are normalized before subscribing.
- [ ] Multiple active projections resolving to the same concrete Topic subscribe only once at the transport layer.
- [ ] Shared Topic transport dedupe does not collapse Collection or Signal projection semantics.
- [ ] Callback failures produce actionable activation errors rather than silent fallback to inference.
- [ ] Tests cover every valid return shape, `nil` failure, duplicate topic normalization, shared transport dedupe, and independent projection delivery.

## Blocked by

- .scratch/alva-declarative-realtime-surface/issues/04-implement-projection-keyed-route-subscription-overrides.md
