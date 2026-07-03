Status: IMPLEMENTATION

# Alva Test Helpers

## Parent

.scratch/alva-phase-10-security/PRD.md

## What to build

Create an `Alva.Test` module containing ergonomic test helpers that allow developers to verify the exact authorization and domain boundary that Vue interacts with. These helpers should wrap `Alva.Dispatcher.dispatch/3` to assert whether a specific event payload returns success or a forbidden error.

## Acceptance criteria

- [ ] `Alva.Test` provides an `assert_dispatch_ok(socket, event, params)` helper that executes the command and asserts an `{:ok, ...}` result.
- [ ] `Alva.Test` provides an `assert_dispatch_forbidden(socket, event, params)` helper that executes the command and asserts a `{:error, %{type: "forbidden"}}` result.
- [ ] A few existing ExUnit tests in the demo application are upgraded to use these helpers to demonstrate their usage.
- [ ] The helpers correctly extract and pass the configured domains and assigns from the provided `socket`.

## Blocked by

None - can start immediately.
