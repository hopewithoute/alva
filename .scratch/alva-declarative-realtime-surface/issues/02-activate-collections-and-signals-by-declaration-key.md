Status: done

# Activate Collections And Signals By Declaration Key

## Parent

.scratch/alva-declarative-realtime-surface/PRD.md

## What to build

Make Collection and Signal page activation use atom Declaration Keys consistently. `collections:` should activate Collection projections by key, and `signals:` should activate Signal projections by key. Signal activation should no longer use browser-facing strings or tuple entries with empty opts. Browser-facing Signal names stay in the resource declaration as `name: "..."` and remain the names Vue listens to through `ash.on`.

This slice should make projection activation identity consistent before Route Subscription and occurrence trigger behavior is tightened.

## Acceptance criteria

- [x] `collections:` activates Collections by atom Declaration Key.
- [x] `signals:` activates Signals by atom Declaration Key.
- [x] Signal activation rejects browser-facing string names.
- [x] Signal activation rejects tuple entries and non-empty opts until a concrete route-owned Signal option exists.
- [x] Duplicate Collection activations fail with an actionable compile-time error.
- [x] Duplicate Signal activations fail with an actionable compile-time error.
- [x] Generated or documented Vue-facing names still come from `name: "..."`, not from activation keys.
- [x] Tests cover both valid Collection/Signal activation and invalid mixed string/tuple Signal activation.

## Blocked by

- .scratch/alva-declarative-realtime-surface/issues/01-fail-loud-on-legacy-page-activation-shapes.md
