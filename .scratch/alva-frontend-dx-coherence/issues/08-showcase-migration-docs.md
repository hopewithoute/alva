Status: ready-for-agent

## What to build

Migrate the demonstration pages in the showcase/sample app to the new V2 architecture. Replace all V1 `collections:` and `route_subscriptions:` blocks with `useAlvaStream` and `useAlvaSignal`. Rewrite the public documentation to teach the Bridge-First surface accurately.

## Acceptance criteria

- [ ] Demo app works end-to-end on V2 architecture.
- [ ] Documentation thoroughly reflects the V2 PRD and ADR 0009.

## Blocked by

- 06-form-and-upload-adapters.md
- 07-resubscription-robustness.md
