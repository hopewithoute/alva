Status: done

## Parent
.scratch/alva-merged-sdk/PRD.md

## What to build
Update the codegen to generate an `ash` composable with typed signal subscriptions. The generated composable should:
- Import `useLiveVue` and `useLiveEvent` from `live_vue` directly
- Export `ash.on(name, input, callback)` with typed signal names and payloads
- Use the generated signal types for strict type safety
- Include the cleanup logic for `onUnmounted`

## Acceptance criteria
- [ ] `mix alva.codegen` generates `composables/ash.ts` with typed signal subscriptions
- [ ] Each signal has a typed `on()` method with correct payload type
- [ ] The generated composable imports from `live_vue`, not from `alva`
- [ ] Signal subscription/unsubscription works correctly

## Blocked by
- Issue 01 (useAlvaApi generation pattern established)
