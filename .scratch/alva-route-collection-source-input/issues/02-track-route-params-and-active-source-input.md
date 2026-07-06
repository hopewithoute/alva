Status: completed

# Track Route Params and Active Source Input in `Alva.LiveView`

## Parent

.scratch/alva-route-collection-source-input/PRD.md

## What to build

Store the latest Route Params and the current Source Input for each active Collection in Alva's LiveView state. Expose a public `route_params(socket)` helper so Source Input callbacks can read URL/path params without relying on app-specific assigns.

## Acceptance criteria

- [ ] Alva private state records current Source Input for each activated Collection.
- [ ] Initial manual and declarative Collection activation both record the Source Input used.
- [ ] `Alva.LiveView.route_params(socket)` returns the latest Route Params known to Alva, defaulting to `%{}` before route params are observed.
- [ ] Tests cover Source Input callbacks deriving input from `route_params(socket)`.
- [ ] Existing Collection activation, subscriptions, streams, and signals continue to pass their current tests.

## Blocked by

- .scratch/alva-route-collection-source-input/issues/01-accept-source-input-as-collection-activation-input.md
