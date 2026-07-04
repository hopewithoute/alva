Status: ready-for-agent

# Migrate Commerce Showcase off Props-Diff Workaround

## Parent

.scratch/alva-collection-liveview-streams/PRD.md

## What to build

Update the commerce showcase to use Alva Collections for route-owned lists instead of plain assigns and `v-diff={false}`. Customer Storefront and Merchant Console should render Collection props from `@streams.*`, and Buy/order lifecycle changes should reflect live without refresh across both surfaces.

This slice proves the library fix on the original failure mode.

## Acceptance criteria

- [ ] Storefront and Merchant Console activate required Collections through declarative options or manual helpers.
- [ ] Route-owned lists are passed to Vue from `@streams.*`, not from plain list assigns.
- [ ] The temporary `v-diff={false}` workaround is removed from showcase LiveVue components.
- [ ] Clicking Buy shows the new order in Storefront Recent Orders without refresh.
- [ ] Merchant Console shows the same order without refresh when open in another window.
- [ ] Browser or LiveView tests cover the no-refresh behavior.
- [ ] Existing seed data, product images, validation, and support chat behavior remain intact.

## Blocked by

- .scratch/alva-collection-liveview-streams/issues/05-apply-immediate-command-results-to-active-collections.md
- .scratch/alva-collection-liveview-streams/issues/06-infer-collection-source-records-from-auto-dto-projection.md
