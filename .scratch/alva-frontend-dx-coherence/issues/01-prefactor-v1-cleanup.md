Status: done
Track: post-migration-cleanup
PRD sequence: Migration step 6 - remove obsolete surfaces after the bridge-first path is proven

## PRD alignment

This is cleanup work, not foundation work. Per the PRD migration path, V1
surfaces should be removed only once the bridge-first command/subscription path
is established and the docs no longer teach the legacy runtime as the default.

## What to build

Remove V1 codebase files that are already strictly obsolete in the current
tree. This includes the V1 Vue composables (`useAlvaQuery`, `useAlvaEvent`,
`useAlvaPageState`) and their references in the SDK index. Public doc
demotion/archival is handled later by the migration-docs issue instead of
blocking this dead-code cleanup slice.

## Acceptance criteria

- [x] V1 composables are deleted from `alva/assets/js`.
- [x] `index.ts` is updated to remove deleted exports.
- [x] Legacy runtime documentation cleanup is explicitly deferred to the final migration-docs slice instead of blocking code deletion here.

## Blocked by

- None - completed cleanup slice
