Status: done

# Retire DataSync Route Collection Workarounds

## Parent

.scratch/alva-demo-new-api-surface/PRD.md

## What to build

Remove the obsolete DataSync route-owned list setup after products and conversations have moved to Collections. The remaining hook behavior should be narrow and explicit, preserving only the realtime setup still needed for non-Collection data such as support messages.

## Acceptance criteria

- [x] DataSync no longer manually loads products or conversations into plain assigns.
- [x] DataSync no longer binds product or conversation read events through route stream queries.
- [x] Storefront and Merchant Console still mount successfully with orders, products, conversations, and support chat behavior intact.
- [x] Any remaining DataSync responsibility is named or documented clearly enough that future contributors do not copy the old route-owned list workaround.
- [x] Tests cover that product and conversation data still renders after the cleanup.

## Blocked by

- .scratch/alva-demo-new-api-surface/issues/01-products-collection-powers-storefront-and-console.md
- .scratch/alva-demo-new-api-surface/issues/02-conversations-collection-powers-merchant-console.md
