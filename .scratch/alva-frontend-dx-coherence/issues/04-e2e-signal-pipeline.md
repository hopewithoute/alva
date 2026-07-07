Status: ready-for-agent

## What to build

Build the end-to-end flow for `kind: :signal`. The backend `handle_event` must intercept `alva:activate_subscription`, check authorization via `Ash.can?` (using `authorize_with`), and subscribe to the derived PubSub topic. The Vue SDK must implement `useAlvaSignal` to send intents and trigger strongly-typed callbacks.

## Acceptance criteria

- [ ] `authorize_with` blocks unauthorized intents with `{:error, :forbidden}`.
- [ ] Authorized intents successfully subscribe the LiveView to the PubSub topic.
- [ ] `useAlvaSignal` manages its lifecycle correctly (deactivates on unmount).

## Blocked by

- 02-global-topic-map-codegen.md
