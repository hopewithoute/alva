Status: ready-for-agent

# Implement Projection-Keyed Route Subscription Overrides

## Parent

.scratch/alva-declarative-realtime-surface/PRD.md

## What to build

Implement top-level `route_subscriptions:` as projection-keyed Topic wiring for already-active Collections and Signals. Overrides should be partial and authoritative: a listed projection uses its explicit Topic wiring, while omitted active projections continue through deterministic inference. Alva validates target projection identity and Topic shape, not whether explicit Topics can be re-derived from Ash publication templates.

## Acceptance criteria

- [ ] `route_subscriptions:` entries are keyed by active projection Declaration Key for both Collections and Signals.
- [ ] `route_subscriptions:` rejects targets that are not activated on the same page.
- [ ] Duplicate `route_subscriptions:` entries for the same projection fail with an actionable compile-time error.
- [ ] Explicit binary Topics are accepted.
- [ ] Explicit Topic lists are accepted.
- [ ] Explicit empty Topic lists are accepted as authoritative opt-outs.
- [ ] Explicit Topic wiring does not attempt to re-derive or reject page-owned Topics solely because they differ from publication templates.
- [ ] Omitted active projections remain eligible for deterministic inference.
- [ ] Tests cover Collection targets, Signal targets, inactive targets, duplicates, explicit Topics, explicit lists, empty lists, and partial overrides.

## Blocked by

- .scratch/alva-declarative-realtime-surface/issues/02-activate-collections-and-signals-by-declaration-key.md
