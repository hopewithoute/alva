Status: done

## What to build

Harden the realtime system against network instability and client state changes. Implement Auto-resubscribe in the Vue SDK so dropped WebSockets gracefully restore subscriptions. Implement reactive `input` ref tracking in `useAlvaStream`. Normalize Ash errors into the `error` ref. Implement `loadMore` pagination for streams.

## Acceptance criteria

- [ ] Dropped websockets gracefully restore subscriptions on reconnect.
- [ ] Changing a reactive input tears down and rebuilds the subscription.
- [ ] Ash Policy errors are cleanly mapped to the Vue `error` ref.
- [ ] `loadMore` handler works without destroying the underlying subscription.

## Blocked by

- 05-e2e-stream-pipeline.md
