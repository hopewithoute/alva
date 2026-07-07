Status: done

## What to build

Remove all V1 codebase files that are strictly obsolete to establish a clean slate. This includes the V1 Vue composables (`useAlvaQuery`, `useAlvaEvent`, `useAlvaPageState`) and their references in the SDK index. V1 ADRs should also be removed or archived.

## Acceptance criteria

- [ ] V1 composables are deleted.
- [ ] `index.ts` is updated to remove deleted exports.
- [ ] V1 ADRs are archived or deleted.

## Blocked by

- None - can start immediately
