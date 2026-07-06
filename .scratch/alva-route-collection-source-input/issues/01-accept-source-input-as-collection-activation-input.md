Status: completed

# Accept `source_input` as Collection Activation Input

## Parent

.scratch/alva-route-collection-source-input/PRD.md

## What to build

Add `source_input` as the preferred route Collection activation option for both manual activation and declarative `collections: [...]`. The existing `params` option should continue to work as a backward-compatible alias, but new tests and docs should exercise `source_input`.

## Acceptance criteria

- [ ] Manual Collection activation accepts static `source_input` and dispatches the source event with that payload.
- [ ] Declarative Collection activation accepts static `source_input` through `use Alva.LiveView`.
- [ ] Callback-based Source Input works with a LiveView callback name.
- [ ] Existing `params` activation behavior remains supported as an alias.
- [ ] Invalid Source Input produces a clear error message using Source Input terminology.

## Blocked by

None - can start immediately
