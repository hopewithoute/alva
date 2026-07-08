Status: done
Track: core-v2
PRD sequence: Follow-up to migration step 2 - resolved decisions 6 and 7 for lifecycle robustness

## PRD alignment

This is follow-up v2 work on top of the typed subscription pipeline. It
hardens reconnect, reactive input changes, pagination, and error surfacing for
the new `useAlvaStream` lifecycle boundary.

## What to build

Harden the realtime system against network instability and client state changes. Implement Auto-resubscribe in the Vue SDK so dropped WebSockets gracefully restore subscriptions. Implement reactive `input` ref tracking in `useAlvaStream`. Normalize Ash errors into the `error` ref. Implement `loadMore` pagination for streams.

## Acceptance criteria

- [x] Dropped websockets gracefully restore subscriptions on reconnect.
- [x] Changing a reactive input tears down and rebuilds the subscription.
- [x] Ash Policy errors are cleanly mapped to the Vue `error` ref.
- [x] `loadMore` handler works without destroying the underlying subscription.

## Blocked by

- None - SDK hardening landed; broader showcase proof continues in `05-e2e-stream-pipeline.md`
