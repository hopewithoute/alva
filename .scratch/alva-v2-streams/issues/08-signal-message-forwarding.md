Status: done

## Parent
.scratch/alva-v2-streams/PRD.md

## What to build
Implement Signal Message Forwarding to Vue clients. Currently, `Alva.LiveView.matching_projection_operations` hardcodes `signals: []`, meaning that valid incoming PubSub messages for signals are caught but dropped on the floor instead of being forwarded to the client. This slice will update the handler to accurately capture signal notifications and pipe them down to the connected Vue instances.

## Acceptance criteria
- [x] Valid signal PubSub messages are properly captured in `handle_info`.
- [x] The `signals` array in the returned projection operation payload correctly forwards these events to the client instead of always being empty.

## Blocked by
None - can start immediately.
