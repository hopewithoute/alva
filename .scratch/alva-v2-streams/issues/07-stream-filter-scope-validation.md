Status: ready-for-agent

## Parent
.scratch/alva-v2-streams/PRD.md

## What to build
Ensure that updated records are correctly validated against their stream's scope. In the initial V2 implementation, `Alva.LiveView.matching_projection_operations` blindly translates an `update` action into a `stream_insert` without validating if the record still meets the conditions of the stream's `source` filter (or `scope`). We need to evaluate the updated record against the original query to decide whether to push a `stream_insert` or a `stream_delete`.

## Acceptance criteria
- [ ] Incoming PubSub `update` notifications evaluate the updated record against the stream's `scope`.
- [ ] If an updated record falls out of scope, it correctly triggers a `stream_delete` instead of a `stream_insert`.

## Blocked by
None - can start immediately.
