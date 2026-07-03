Status: ready-for-agent

# Runtime Authentication Warnings & Telemetry

## Parent

.scratch/alva-phase-10-security/PRD.md

## What to build

Modify the `Alva.Dispatcher` to emit the Actor/Tenant Omission Warning when executing actions without authentication contexts, and to emit Alva Telemetry Events. This provides developers with clear feedback when they forget to assign a user to the socket and provides standard hooks for system auditing.

## Acceptance criteria

- [ ] A `Logger.warning` is emitted by the dispatcher if `current_user` or `current_tenant` (or the equivalent configurable keys) are missing from `socket.assigns` when dispatching.
- [ ] The dispatcher calls `:telemetry.execute([:alva, :dispatch, :stop], measurements, metadata)` after an event runs.
- [ ] Telemetry metadata includes the actor, event name, action parameters, and the result.
- [ ] Tests verify that the warning is logged for omitted actors.
- [ ] Tests verify that telemetry events are fired upon dispatch.

## Blocked by

None - can start immediately.
