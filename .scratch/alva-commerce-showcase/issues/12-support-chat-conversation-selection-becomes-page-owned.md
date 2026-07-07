Status: done

# Support Chat Conversation Selection Becomes Page-Owned

## Parent

.scratch/alva-commerce-showcase/PRD.md

## What to build

Make the active Support Chat Conversation explicit page-owned state for both Customer Storefront and Merchant Console. The selected Conversation should become the stable page scope that drives transcript loading and realtime wiring, so shopper and merchant chat behavior no longer depends on implicit Vue-only coordination or stale in-flight requests.

## Acceptance criteria

- [ ] Customer Storefront and Merchant Console expose an explicit page-owned active Conversation contract for Support Chat behavior.
- [ ] Changing Customer Name or selecting a different Conversation refreshes transcript ownership through the current active Conversation without leaking stale request results.
- [ ] Existing Support Chat behavior remains intact for shopper join, merchant selection, and cross-surface messaging.
- [ ] The active Conversation ownership model is documented clearly enough that future Support Chat work does not reintroduce implicit page-local coordination.
- [ ] Tests cover active Conversation selection, reset behavior, and stale-request protection on both chat surfaces.

## Blocked by

None - can start immediately
