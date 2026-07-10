Status: ready-for-agent

## Parent

.scratch/alva-sdk-dx-overhaul/PRD.md

## What to build

Finalize the API Surface unification by mounting LiveView uploads and purging legacy code.

Bind `useAlvaUpload` to the root object as `alva.use_upload(name)`. Then, migrate all remaining components in the codebase that use `useAlvaApi`, `useAlvaForm` (with strings), or `ash.on` over to the new `useAlva` surface. Finally, delete the legacy files (`useAlvaApi.ts`, `ash.ts`) to enforce the new standard.

## Acceptance criteria

- [ ] `alva.use_upload` is generated and available.
- [ ] All remaining `useAlvaApi` usages are migrated.
- [ ] All remaining `ash.on` usages are migrated.
- [ ] Legacy SDK files are removed from the generator and the codebase.
- [ ] The entire test suite and build succeeds.

## Blocked by

- .scratch/alva-sdk-dx-overhaul/issues/03-form-hook-integration.md
- .scratch/alva-sdk-dx-overhaul/issues/04-reactive-query-builder.md
