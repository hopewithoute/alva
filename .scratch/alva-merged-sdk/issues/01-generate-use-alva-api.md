Status: done

## Parent
.scratch/alva-merged-sdk/PRD.md

## What to build
Update the codegen to generate a `useAlvaApi` composable with per-event methods instead of a generic `call(event, payload)` interface. The generated composable should:
- Import `useLiveVue` from `live_vue` directly
- Export one method per declared event (e.g., `call.catalog.list_products(payload)`)
- Use the generated event types for strict type safety
- Include the `onSuccess` and `onError` callbacks from the current implementation

## Acceptance criteria
- [ ] `mix alva.codegen` generates `composables/useAlvaApi.ts` with per-event methods
- [ ] Each event has a typed method with correct input/output types
- [ ] The generated composable imports from `live_vue`, not from `alva`
- [ ] The generated types match the backend dispatcher return format

## Blocked by
None - can start immediately
