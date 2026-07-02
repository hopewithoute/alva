# 24 - ashCall (RPC Mutations Foundation)

Status: done

## Parent
`.scratch/alva/PRD.md` (Phase 6)

## What to build
The core `useAlvaApi()` and `ashCall` interface for Vue. This wrapper will sit on top of LiveVue's event pushing capability to dispatch domain intents (like "students.create") to the server. It must cleanly unwrap or return the normalized `LiveResult` (`{ ok: true, data }` or `{ ok: false, error }`) established in Phase 5, providing a predictable Promise-based API for mutations.

## Acceptance criteria
- [ ] Implement `useAlvaApi()` composable that provides the `call` function.
- [ ] `ashCall` executes an event against the LiveView backend and returns a Promise.
- [ ] Resolves the Promise with the normalized `LiveResult` payload.
- [ ] Includes basic configuration for global hooks (e.g. `onError`, `onSuccess`).

## Blocked by
None - can start immediately
