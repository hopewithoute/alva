Status: done
Track: core-v2
PRD sequence: Supporting work for migration step 2 - keep thin Ash wrappers over LiveVue primitives

## PRD alignment

This is supporting v2 work. The PRD keeps `useAlvaForm` and `useAlvaUpload`,
but only as thin Ash-aware wrappers over `useLiveForm()` and `useLiveUpload()`
rather than as a new page runtime.

## What to build

Refactor `useAlvaForm` to be a thin Ash validation wrapper natively layered over `useLiveForm()`. Implement the `commands: [...]` allowlist on the LiveView to securely inject `allow_upload` configuration for `ash_storage` without relying on the V1 page DSL.

## Acceptance criteria

- [x] `useAlvaForm` delegates core form state to `useLiveForm()`.
- [x] `commands: [...]` allowlist securely authorizes upload parameters.
- [x] `useAlvaUpload` seamlessly interfaces with `ash_storage`.

## Blocked by

- None - completed supporting v2 slice
