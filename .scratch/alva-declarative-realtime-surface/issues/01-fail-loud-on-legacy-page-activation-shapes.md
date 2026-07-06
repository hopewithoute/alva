Status: done

# Fail Loud On Legacy Page Activation Shapes

## Parent

.scratch/alva-declarative-realtime-surface/PRD.md

## What to build

Lock the public LiveView activation surface to the final declarative API and reject legacy or ambiguous activation shapes with clear errors. Page authors should only be able to use keyword-form declarative activation with `collections:`, `signals:`, and `route_subscriptions:`. Old declarative `subscriptions:`, declarative `streams:`, legacy tuple forms, nested Collection `params:`, and nested Collection `subscriptions:` must fail loudly instead of falling through compatibility paths.

This slice should keep imperative Alva helpers and raw Phoenix PubSub available as escape hatches; only unsupported declarative activation shapes are removed.

## Acceptance criteria

- [x] Keyword-form `use Alva.LiveView` accepts only the public declarative keys `collections:`, `signals:`, and `route_subscriptions:` plus existing non-activation configuration such as domains.
- [x] Legacy tuple-form activation fails with an actionable compile-time error.
- [x] Top-level declarative `subscriptions:` fails with an actionable compile-time error.
- [x] Top-level declarative `streams:` fails with an actionable compile-time error.
- [x] Nested Collection `params:` fails and points developers to `source_input:`.
- [x] Nested Collection `subscriptions:` fails and points developers to top-level `route_subscriptions:`.
- [x] Imperative Alva subscription helpers and raw Phoenix PubSub remain usable outside the declarative activation allowlist.
- [x] Tests assert public error behavior rather than private helper names.

## Blocked by

None - can start immediately.
