Status: ready-for-agent

## What to build

Refactor `Alva.Dispatcher` to remove server-side optimistic projection upon command success. All data must enter streams exclusively via the PubSub fan-out `handle_info` listener to prevent race conditions and enforce a single canonical path for stream updates.

## Acceptance criteria

- [ ] Command success no longer manually mutates the LiveView stream.
- [ ] Tests relying on optimistic projection are updated to wait for PubSub broadcasts.

## Blocked by

- None - can start immediately
