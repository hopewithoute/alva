Status: ready-for-agent

## What to build

Build the end-to-end flow for `kind: :stream`. Eager streams (`activate: :mount`) use native `Phoenix.LiveView.stream/3` without loading flicker. Lazy streams run the `source event` upon receiving the intent. `useAlvaStream` manages the lifecycle and receives data implicitly through LiveVue props.

## Acceptance criteria

- [ ] Eager streams are populated during `mount`.
- [ ] `useAlvaStream` suppresses `isLoading` if eager data is present.
- [ ] Lazy streams execute the `source event` when `useAlvaStream` sends the activation intent.

## Blocked by

- 04-e2e-signal-pipeline.md
