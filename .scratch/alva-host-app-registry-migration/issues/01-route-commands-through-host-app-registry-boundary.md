Status: done

# Route Commands Through Host App Registry Boundary

## What to build

Move Alva command resolution onto a Host App Registry Boundary keyed by the consumer app's `otp_app` and configured `ash_domains`, so generated SDK calls and runtime dispatch both resolve Commands application-wide instead of narrowing through page-scoped Domain lists. This slice should prove a complete command path from code generation through runtime dispatch and compile-time uniqueness validation in the host app, while keeping resource-local Collection Source event references unchanged.

## Acceptance criteria

- [x] Generated Alva command bindings and runtime dispatch both resolve exposed command names from the same Host App Registry Boundary.
- [x] Runtime command dispatch no longer requires or accepts page-scoped `domains:` input for normal host-app usage.
- [x] Host-app compile-time verification fails when two Domains expose the same command name in one `ash_domains` application.
- [x] Compiling Alva standalone without a host app registry context remains a safe no-op for host-app-level verification.
- [x] Tests cover successful application-wide command dispatch, duplicate command-name failure, and code generation using the shared registry seam.

## Blocked by

None - can start immediately
