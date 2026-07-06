Status: completed

# Add Explicit Collection Refresh Helpers

## Parent

.scratch/alva-route-collection-source-input/PRD.md

## What to build

Add public helpers for explicit Collection Refresh. A caller should be able to refresh a Collection using its current Source Input, or refresh it once with provided Source Input, without reconstructing low-level activation options.

## Acceptance criteria

- [ ] `reload_collection(socket, name)` refreshes an active Collection using its stored current Source Input.
- [ ] `reload_collection(socket, name, source_input: input)` refreshes using the provided Source Input.
- [ ] Refreshing an inactive or unknown Collection fails with a clear error.
- [ ] Manual refresh uses the same Collection source and stream reset behavior as route-change refresh.
- [ ] Tests cover manual refresh after initial activation and after Source Input has changed.

## Blocked by

- .scratch/alva-route-collection-source-input/issues/02-track-route-params-and-active-source-input.md
