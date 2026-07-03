Status: done

## Parent
`docs/prd.md` (Phase 8 - Forms Integration)

## What to build
Implement a server-side dry-run mechanism to validate form states in real-time (debouncing) without committing data to the database. Add a `validate_only: true` flag in the Alva event DSL (or adapt generic action behavior). `Alva.Dispatcher.dispatch/3` must be updated to process these events by executing `Ash.Changeset` or `Ash.ActionInput` validation strictly, returning early with `LiveError` if invalid, or a simulated `{ok: true}` success shape if valid. This serves as the backend support for `ashForm`'s `validateEvent`.

## Acceptance criteria
- [x] Alva DSL supports declaring an event strictly for validation (e.g. `validate_only: true`).
- [x] The `Alva.Dispatcher` executes the target Ash action securely as a dry-run (e.g., stopping after validation but before DB commit).
- [x] Returns properly shaped `LiveResult` (`ok: true` if valid, `ok: false, error: LiveError` if invalid).
- [x] Validated by ExUnit tests verifying no database side-effects occur.

## Blocked by
None - can start immediately
