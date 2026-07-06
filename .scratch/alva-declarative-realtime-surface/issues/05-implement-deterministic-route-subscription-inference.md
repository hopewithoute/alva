Status: done

# Implement Deterministic Route Subscription Inference

## Parent

.scratch/alva-declarative-realtime-surface/PRD.md

## What to build

Implement the default Route Subscription inference path for active projections whose Topic set is static, finite, and derivable from resource projection and Ash PubSub declarations. Inference should make simple pages concise while failing loudly whenever Alva cannot prove the exact Topic set.

This slice should not broaden scope implicitly. If a projection trigger matches multiple publications, depends on Page Scope, depends on callback-generated Topics, or otherwise cannot be derived statically, activation should require explicit `route_subscriptions:`.

## Acceptance criteria

- [x] A simple active Collection with one static publication can infer its Topic wiring.
- [x] A simple active Signal with one static publication can infer its Topic wiring.
- [x] A single publication expanding to multiple static Topics remains inferable.
- [x] A projection trigger matching more than one publication fails inference as ambiguous.
- [x] Publication topic callbacks are not considered deterministic.
- [x] Page Scope-dependent Topic wiring is not inferred.
- [x] Inference failures are activation-time errors with messages that identify the affected projection and why inference failed.
- [x] Explicit `route_subscriptions:` overrides bypass inference for the listed projection.
- [x] Tests cover deterministic success, multi-topic static success, ambiguous publication failure, callback topic failure, Page Scope-dependent failure, and explicit override behavior.

## Blocked by

- .scratch/alva-declarative-realtime-surface/issues/03-separate-collection-source-events-from-pubsub-occurrence-triggers.md
- .scratch/alva-declarative-realtime-surface/issues/04-implement-projection-keyed-route-subscription-overrides.md
