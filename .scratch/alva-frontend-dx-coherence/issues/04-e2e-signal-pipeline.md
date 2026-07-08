Status: done
Track: core-v2
PRD sequence: Migration step 2 - add typed signal activation on top of the backend registry

## PRD alignment

This is primary v2 work. Runtime scaffolding for typed signal activation now
exists, but the signal path is not yet fully proven end-to-end against the
subscription registry, generated types, and showcase demo.

## What to build

Complete the end-to-end flow for `kind: :signal`. Migrate signal capabilities
onto the subscription registry, ensure codegen emits signal payload typing, and
prove the demo notification path with the public `useAlvaSignal` wrapper. The
backend `handle_event` path should enforce the page allowlist, validate public
input, check authorization via `Ash.can?` (`authorize_with`), and subscribe to
the derived PubSub topic.

## Acceptance criteria

- [x] Resource-level `kind :signal` subscriptions persist into the host-app registry and generated `AlvaSubscriptions`.
- [x] Page allowlists declared through `use Alva.LiveView, subscriptions: [...]` are enforced.
- [x] `authorize_with` blocks unauthorized intents with `{:error, :forbidden}`.
- [x] Authorized intents successfully subscribe the LiveView to the PubSub topic.
- [x] `useAlvaSignal` round-trips successfully in the demo notification flow and deactivates on unmount.

## Blocked by

- None - foundation/runtime scaffolding exists; this is the remaining signal proof slice
