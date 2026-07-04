Status: done

# Showcase Validation Gate

## What to build

Add the final validation gate for the Alva Commerce Showcase. This issue should verify that the complete sample works as a cohesive demo, passes the expected project commands, and remains inside the PRD scope.

## Acceptance criteria

- [x] `mix precommit` passes for the completed showcase.
- [x] `mix assets.build` passes for the LiveVue/shadcn-vue frontend integration.
- [x] Route-level tests cover Customer Storefront catalog rendering, Customer Name capture, simple Order creation, Order Lifecycle visibility, and customer-side Support Chat.
- [x] Route-level tests cover Merchant Console order visibility, lifecycle advancement, invalid transition prevention, Product Media upload controls, Inventory Snapshot behavior, and merchant-side Support Chat.
- [x] The implementation does not reintroduce old Student, Academics, Communication, primitive demo routes, or PostgreSQL migrations.
- [x] The completed showcase remains within the PRD's out-of-scope boundaries.

## Blocked by

- 01-bootstrap-commerce-showcase-shell
- 02-seed-product-catalog-through-alva
- 03-place-orders-from-customer-storefront
- 04-operate-order-lifecycle-in-merchant-console
- 05-synchronize-orders-across-surfaces
- 06-adjust-inventory-snapshot
- 07-upload-product-media-end-to-end
- 08-support-chat-between-shopper-and-merchant
- 09-expose-showcase-typed-client-contracts
