# 22 - Result Strategies: Push Event, Navigate, and Custom Modules

Status: done

## Parent

`docs/prd.md` (Phase 4 / Result Strategies)

## What to build

Implement the remaining flexibility strategies in `Alva.Result`: `push_event`, `navigate` (or `patch`), and `{:custom, module}` delegation. This allows developers to execute complex or bespoke side effects (like redirecting users or pushing JS interop events) after an event executes.

## Acceptance criteria

- [ ] Strategy `push_event` calls `Phoenix.LiveView.push_event/3`.
- [ ] Strategy `navigate` or `patch` handles LiveView navigation correctly.
- [ ] Strategy `{:custom, module}` delegates the socket transformation to a custom module (e.g., `Module.handle_result/2`).
- [ ] Tests verify that all three strategies correctly transform the socket or return the appropriate tuple.

## Blocked by

- `.scratch/alva/issues/21-result-strategy-assign-and-reply-only.md`
