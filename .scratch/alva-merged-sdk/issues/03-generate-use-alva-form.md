Status: done

## Parent
.scratch/alva-merged-sdk/PRD.md

## What to build
Update the codegen to generate a `useAlvaForm` composable with typed form submission. The generated composable should:
- Import `useLiveForm` from `live_vue` directly
- Export `useAlvaForm(submitEvent, options)` with typed submit event and form values
- Use the generated event types for strict type safety
- Include the Ash validation error sync logic

## Acceptance criteria
- [ ] `mix alva.codegen` generates `composables/useAlvaForm.ts` with typed form submission
- [ ] The submit event is typed with correct input/output types
- [ ] The generated composable imports from `live_vue`, not from `alva`
- [ ] Form validation errors are synced correctly

## Blocked by
- Issue 01 (useAlvaApi generation pattern established)
