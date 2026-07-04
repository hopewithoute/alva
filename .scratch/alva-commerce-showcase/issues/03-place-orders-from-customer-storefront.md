Status: ready-for-agent

# Place Orders From Customer Storefront

## What to build

Allow a shopper to enter a Customer Name and place a simple Order for a Product from the Customer Storefront. The submitted Order should go through Alva action dispatch, become visible on the Customer Storefront, and start in the `new` Order Lifecycle state.

## Acceptance criteria

- [ ] An Order resource records Customer Name, Product reference, quantity, and Order Lifecycle status.
- [ ] Order creation uses an explicit Alva event and does not trust client-provided domain authority beyond the submitted intent.
- [ ] The Customer Storefront lets a shopper enter a Customer Name and submit a simple Order for a Product.
- [ ] The Customer Storefront shows the submitted Order with its `new` Order Lifecycle status.
- [ ] Tests cover Customer Name capture, Order creation, Order visibility, and dispatcher routing.
- [ ] The slice stays out of cart, payment, account, shipping, tax, and discount behavior.

## Blocked by

- 02-seed-product-catalog-through-alva
