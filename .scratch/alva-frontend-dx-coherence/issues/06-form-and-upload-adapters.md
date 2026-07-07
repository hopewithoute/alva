Status: done

## What to build

Refactor `useAlvaForm` to be a thin Ash validation wrapper natively layered over `useLiveForm()`. Implement the `commands: [...]` allowlist on the LiveView to securely inject `allow_upload` configuration for `ash_storage` without relying on the V1 page DSL.

## Acceptance criteria

- [ ] `useAlvaForm` delegates core form state to `useLiveForm()`.
- [ ] `commands: [...]` allowlist securely authorizes upload parameters.
- [ ] `useAlvaUpload` seamlessly interfaces with `ash_storage`.

## Blocked by

- 01-prefactor-v1-cleanup.md
