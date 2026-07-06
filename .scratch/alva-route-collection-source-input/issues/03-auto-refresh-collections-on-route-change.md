Status: completed

# Auto Refresh Collections on Route Change

## Parent

.scratch/alva-route-collection-source-input/PRD.md

## What to build

Add `reload_on: :route_change` to route Collection activation. When Phoenix route params change, Alva should recompute Source Input for opted-in Collections, compare it against the previous Source Input, and refresh only Collections whose Source Input changed.

## Acceptance criteria

- [ ] `reload_on: :route_change` attaches route lifecycle handling through Alva.LiveView.
- [ ] Route Params are stored before Source Input callbacks run.
- [ ] A Collection with changed Source Input is refreshed through the server-owned Collection path.
- [ ] A Collection with unchanged Source Input is not redundantly refreshed.
- [ ] Multiple route-change Collections on the same LiveView refresh independently based on their own Source Input.
- [ ] Route-change refresh preserves existing route subscription and Collection operation behavior.

## Blocked by

- .scratch/alva-route-collection-source-input/issues/02-track-route-params-and-active-source-input.md
