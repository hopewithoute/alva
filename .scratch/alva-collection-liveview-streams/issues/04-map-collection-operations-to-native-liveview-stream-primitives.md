Status: ready-for-agent

# Map Collection Operations to Native LiveView Stream Primitives

## Parent

.scratch/alva-collection-liveview-streams/PRD.md

## What to build

Project incoming Ash PubSub occurrences into active Collections by calling Phoenix LiveView stream primitives directly. Alva should not implement its own dedupe, missing-update, limit, or ordering semantics; it should pass through native LiveView stream options where declared.

The core mapping is `insert` to `stream_insert`, `update` to `stream_insert(update_only: true)`, and `delete` to `stream_delete`.

## Acceptance criteria

- [ ] `insert on: "...", at: 0` calls `stream_insert` with the declared `at` option.
- [ ] `update on: "..."` calls `stream_insert` with `update_only: true` by default.
- [ ] Native LiveView options such as `at`, `limit`, and `update_only` can be passed through where appropriate.
- [ ] `delete on: "..."` calls `stream_delete` for the projected item.
- [ ] Collection operations run only for active Collections on the current LiveView.
- [ ] Inactive Collections ignore matching PubSub occurrences.
- [ ] Tests prove LiveVue receives stream diffs through `@streams` rather than props-diff changes.

## Blocked by

- .scratch/alva-collection-liveview-streams/issues/01-introduce-collection-dsl-as-liveview-stream-contract.md
- .scratch/alva-collection-liveview-streams/issues/02-activate-collections-declaratively-in-liveviews.md
