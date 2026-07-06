Status: ready-for-agent

# Separate Collection Source Events From PubSub Occurrence Triggers

## Parent

.scratch/alva-declarative-realtime-surface/PRD.md

## What to build

Separate command/read Event Declaration Keys from PubSub Occurrence Keys in resource projections. A Collection `source event:` references a command/read Event Declaration Key because it executes a load path. Collection delta operations and Signal projections use `on:` to reference PubSub Occurrence Keys, normally the Ash action atom passed to `publish`.

The goal is to prevent `on:` from being mistaken for a client command, browser-facing event name, raw PubSub event string, or concrete Topic.

## Acceptance criteria

- [ ] Collection `source event:` resolves command/read Event Declaration Keys.
- [ ] Collection `source event:` failures name the missing or invalid source declaration clearly.
- [ ] Collection `insert`, `update`, and `delete` `on:` values resolve PubSub Occurrence Keys.
- [ ] Signal `on:` values resolve PubSub Occurrence Keys.
- [ ] `on:` rejects command Event Declaration Keys when they do not correspond to a PubSub occurrence key.
- [ ] `on:` rejects browser-facing names such as `"orders.fulfill"`.
- [ ] `on:` rejects concrete Topic strings such as `"orders:all"`.
- [ ] `on:` rejects raw PubSub event strings when they are not the occurrence key syntax.
- [ ] Tests cover valid source loading, valid occurrence-triggered Collection deltas, valid Signal projection, and each invalid `on:` category.

## Blocked by

- .scratch/alva-declarative-realtime-surface/issues/02-activate-collections-and-signals-by-declaration-key.md
