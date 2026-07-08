Status: done
Track: core-v2
PRD sequence: Migration step 2 follow-up - apply resolved decision 8 before showcase migration

## PRD alignment

This issue implements the PRD decision that stream updates must arrive through
the PubSub fan-out path only. Command reply handling should not mutate route
state directly once the subscription activation pipeline is in place.

## What to build

Refactor `Alva.Dispatcher` to remove server-side optimistic projection upon
command success. All data must enter streams exclusively via the PubSub
fan-out `handle_info` listener for active subscriptions to prevent race
conditions and enforce a single canonical path for stream updates.

## Acceptance criteria

- [x] Command success no longer manually mutates the LiveView stream.
- [x] Stream updates arrive only through the resolved subscription notification path.
- [x] The runtime now treats PubSub fan-out as the canonical stream update path; remaining end-to-end confidence work continues in the stream pipeline issue.

## Blocked by

- None - implementation landed; broader end-to-end proof continues in `05-e2e-stream-pipeline.md`
