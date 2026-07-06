Status: ready-for-agent

# Migrate Showcase Routes To The Final Declarative Surface

## Parent

.scratch/alva-declarative-realtime-surface/PRD.md

## What to build

Update the showcase and demo routes so they demonstrate only the final declarative realtime surface. Route-owned lists should remain on Collection props, Signals should use atom-key activation with browser-facing `name: "..."`, and Topic wiring should use projection-keyed `route_subscriptions:` where explicit or dynamic wiring is needed. No demo route should rely on legacy declarative `subscriptions:`, declarative `streams:`, nested Collection `subscriptions:`, nested Collection `params:`, or client-owned shadow query caches for route-owned lists.

This slice proves the complete API surface end-to-end through the app that developers will read first.

## Acceptance criteria

- [ ] Showcase LiveViews use `collections:`, `signals:`, and `route_subscriptions:` as the only declarative realtime activation keys.
- [ ] Showcase routes do not use legacy declarative `subscriptions:` or declarative `streams:`.
- [ ] Showcase Collection activation uses `source_input:` instead of nested `params:`.
- [ ] Showcase Topic wiring uses top-level projection-keyed `route_subscriptions:` where explicit wiring is needed.
- [ ] Showcase Signals activate by atom Declaration Key and expose browser names through resource `name: "..."`.
- [ ] Route-owned orders, products, and conversations render from Collection props rather than client-owned query caches.
- [ ] Vue code does not manually reconcile route-owned Collection state through shadow query arrays.
- [ ] Existing showcase behaviors for ordering, fulfillment, product media, support conversations, and realtime notifications remain covered by tests.
- [ ] Tests or grep-based assertions prevent reintroducing old declarative activation shapes in showcase routes.

## Blocked by

- .scratch/alva-declarative-realtime-surface/issues/01-fail-loud-on-legacy-page-activation-shapes.md
- .scratch/alva-declarative-realtime-surface/issues/02-activate-collections-and-signals-by-declaration-key.md
- .scratch/alva-declarative-realtime-surface/issues/03-separate-collection-source-events-from-pubsub-occurrence-triggers.md
- .scratch/alva-declarative-realtime-surface/issues/04-implement-projection-keyed-route-subscription-overrides.md
- .scratch/alva-declarative-realtime-surface/issues/05-implement-deterministic-route-subscription-inference.md
- .scratch/alva-declarative-realtime-surface/issues/06-support-dynamic-route-subscription-callback-semantics.md
