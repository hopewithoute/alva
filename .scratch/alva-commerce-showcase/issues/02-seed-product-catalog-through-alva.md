Status: done

# Seed Product Catalog Through Alva

## What to build

Add a minimal ETS-backed Product catalog and expose it through Alva so the Customer Storefront can render seeded Product records with names, descriptions, prices, stock availability, and Product Media references. This should be the first end-to-end domain path through Ash Resource actions, Alva dispatch, LiveVue, and route-level tests.

## Acceptance criteria

- [ ] A Product resource exists with public fields for name, description, price, stock, and media reference.
- [ ] Seeded Product data is available immediately after startup and resets predictably on restart.
- [ ] A stable Alva event exposes Product listing through the Product resource.
- [ ] The Customer Storefront renders the seeded Product catalog from the Alva-backed data path.
- [ ] Tests cover the Product action contract, Alva dispatcher routing, and Customer Storefront catalog rendering.
- [ ] Product state uses ETS-backed Ash resources and does not introduce PostgreSQL persistence.

## Blocked by

- 01-bootstrap-commerce-showcase-shell
