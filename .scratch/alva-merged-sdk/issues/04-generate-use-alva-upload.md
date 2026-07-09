Status: done

## Parent
.scratch/alva-merged-sdk/PRD.md

## What to build
Update the codegen to generate a `useAlvaUpload` composable with typed upload handling. The generated composable should:
- Import `useLiveUpload` from `live_vue` directly
- Export `useAlvaUpload(name, options)` with typed upload field names
- Use the generated file argument types for strict type safety
- Include the upload lifecycle handling (validate, save)

## Acceptance criteria
- [ ] `mix alva.codegen` generates `composables/useAlvaUpload.ts` with typed upload handling
- [ ] Upload field names are typed from the resource definition
- [ ] The generated composable imports from `live_vue`, not from `alva`
- [ ] Upload progress and file references work correctly

## Blocked by
- Issue 01 (useAlvaApi generation pattern established)
