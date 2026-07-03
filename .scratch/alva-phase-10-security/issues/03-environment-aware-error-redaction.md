Status: IMPLEMENTATION

# Environment-Aware Error Redaction

## Parent

.scratch/alva-phase-10-security/PRD.md

## What to build

Implement the Error Redaction Rule in `Alva.Error`. When operating in a production environment, any unhandled internal server error or crash must be sanitized into a generic `unknown` error payload, stripping stack traces and sensitive details before hitting Vue. In development, the full details remain available to the client.

## Acceptance criteria

- [ ] `Alva.Error` detects the application environment (e.g., via `Mix.env()` or a config variable).
- [ ] In production, internal/unexpected errors are transformed into `{ type: "unknown", message: "An unexpected error occurred" }`.
- [ ] In development, internal/unexpected errors retain their full message in the Vue payload.
- [ ] The complete error and stack trace are logged to the server console regardless of the environment.
- [ ] Tests verify the environment-aware redaction behavior by mocking or configuring the environment.

## Blocked by

None - can start immediately.
