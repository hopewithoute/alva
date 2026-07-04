Status: completed

# Expose Showcase Typed Client Contracts

## What to build

Make the showcase's generated client event contracts visible and used by the Vue surfaces so the demo validates Alva's typed frontend experience. The generated contracts should include Product, Order, Inventory Snapshot, Product Media, Conversation, and SupportMessage events introduced by the previous slices.

## Acceptance criteria

- [x] Showcase events are included in generated TypeScript contracts.
- [x] Vue surfaces use the generated contracts for Alva command calls and signal callbacks.
- [x] Wrong event names or wrong input shapes fail TypeScript in the showcase build/test path.
- [x] Generated files are placed in the established isolated output location and do not collide with hand-written code.
- [x] Tests or build checks prove the typed client contract is healthy.

## Blocked by

- 02-seed-product-catalog-through-alva
- 03-place-orders-from-customer-storefront
- 04-operate-order-lifecycle-in-merchant-console
- 06-adjust-inventory-snapshot
- 07-upload-product-media-end-to-end
- 08-support-chat-between-shopper-and-merchant
