# 27 - ashForm (Server-Validated Form State)

Status: done

## Parent
`.scratch/alva/PRD.md` (Phase 6)

## What to build
A specialized Vue form composable `ashForm` that handles form state, submission logic, and debounce interactions. It will automatically map the normalized validation errors (`fields` mapping) returned by `ashCall` into the UI's reactive state so that input components can seamlessly display server-side validation errors without relying on heavy client-side schema validation (e.g., Zod).

## Acceptance criteria
- [ ] Implement `ashForm` managing form values, loading state, and submission.
- [ ] Automatically maps validation errors from the server's `LiveError` into field-level reactive states.
- [ ] Includes support for debounce validation for real-time form checks.

## Blocked by
- Issue 24 (`ashCall`)
