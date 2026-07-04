Status: done

# Products Collection Powers Storefront And Console

## Parent

.scratch/alva-demo-new-api-surface/PRD.md

## What to build

Move the showcase product list onto the new Alva Collection API surface end to end. Storefront and Merchant Console should receive products from the server-owned Collection stream, while stock adjustments and media uploads continue to update both surfaces without manual refresh.

## Acceptance criteria

- [x] Products are defined as an Alva Collection with an explicit source event and PubSub-backed update operations.
- [x] Storefront and Merchant Console activate the products Collection through declarative LiveView options or an equally explicit helper.
- [x] Storefront and Merchant Console pass products to Vue from `@streams.products`, not from a plain list assign.
- [x] Stock adjustments update the rendered product list without manually re-fetching the route-owned list.
- [x] Product media uploads still work and updated media references render without refresh.
- [x] Existing product seed data and product image behavior remain intact.

## Blocked by

None - can start immediately
