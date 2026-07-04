Status: ready-for-agent

# Activate Collections Declaratively in LiveViews

## Parent

.scratch/alva-collection-liveview-streams/PRD.md

## What to build

Allow LiveViews to activate declared Collections either manually or through declarative `use Alva.LiveView` options. A simple page should be able to list the Collections it needs without writing mount boilerplate, while the render function still explicitly passes `@streams.collection_name` into the Vue component.

This slice should load the Collection source event, initialize the Phoenix LiveView stream, and make the stream available under `@streams`.

## Acceptance criteria

- [ ] `use Alva.LiveView, collections: [:sales_orders]` activates only the allowlisted Collections.
- [ ] `Alva.LiveView.collection(socket, :sales_orders)` activates the same Collection manually.
- [ ] Activating a Collection dispatches its explicit source event with `%{}` by default.
- [ ] Source records are streamed with `stream(socket, name, records, reset: true)` rather than assigned as a plain prop.
- [ ] No Collection is activated merely because its domain is mounted.
- [ ] Unknown Collection activation fails with an actionable error.
- [ ] A LiveView test can render a Vue component with `sales_orders={@streams.sales_orders}` after activation.

## Blocked by

- .scratch/alva-collection-liveview-streams/issues/01-introduce-collection-dsl-as-liveview-stream-contract.md
