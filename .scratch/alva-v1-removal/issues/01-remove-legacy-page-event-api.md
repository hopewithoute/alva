Status: ready-for-agent

## What to build

Remove the `usePageEvent` composable and the `on()` helper function from the frontend TypeScript assets. These APIs were part of the V1 page events implementation and are no longer supported in the V2 model (superseded by `useAlvaSignal` and command bindings).

This is a clean-up of technical debt and intentionally introduces a breaking change for any consumer apps still using these legacy APIs.

## Acceptance criteria

- [ ] Delete `alva/assets/js/usePageEvent.ts`.
- [ ] Delete the corresponding test file `alva/assets/js/usePageEvent.spec.ts`.
- [ ] Remove the `on()` backward-compatibility helper method from `alva/assets/js/useAlvaApi.ts`.
- [ ] Remove any exports related to `usePageEvent` or `on` from `alva/assets/js/index.ts`.
- [ ] Ensure all TS tests pass without these files.

## Blocked by

None - can start immediately
