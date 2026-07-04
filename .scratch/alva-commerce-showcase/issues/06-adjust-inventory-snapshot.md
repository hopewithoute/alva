Status: ready-for-agent

# Adjust Inventory Snapshot

## What to build

Let merchant staff adjust Product stock from the Merchant Console and have the Inventory Snapshot and Customer Storefront catalog reflect the updated stock through Alva-backed Product actions. The behavior should remain a lightweight sample, not a warehouse or accounting system.

## Acceptance criteria

- [ ] Product stock can be adjusted through an explicit Alva event backed by a Product action.
- [ ] The Merchant Console shows the updated Inventory Snapshot after a stock adjustment.
- [ ] The Customer Storefront catalog reflects updated stock availability.
- [ ] Tests cover valid stock adjustment, visible Inventory Snapshot changes, and Customer Storefront catalog updates.
- [ ] The implementation avoids warehouse management, full inventory accounting, and unrelated commerce scope.

## Blocked by

- 04-operate-order-lifecycle-in-merchant-console
