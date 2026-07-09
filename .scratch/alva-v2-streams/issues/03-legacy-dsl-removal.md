Status: completed

## Parent
.scratch/alva-v2-streams/PRD.md

## What to build
Remove the V1 legacy architecture.
1. Delete the `subscription` DSL block from `Alva.Extension` completely.
2. This must trigger a hard compiler rejection for any remaining usages in the codebase.
3. Clean up the entire test suite associated with `subscription` DSL within the framework. Remove all stale assertions and ensure the core framework test suite passes natively without legacy code.

## Acceptance criteria
- [x] `subscription` DSL no longer compiles (throws CompileError).
- [x] All framework-level legacy `subscription` tests are cleaned up and completely removed.
- [x] Core SDK tests pass cleanly.

## Blocked by
- .scratch/alva-v2-streams/issues/01-client-driven-signals.md
- .scratch/alva-v2-streams/issues/02-stateful-server-streams.md
