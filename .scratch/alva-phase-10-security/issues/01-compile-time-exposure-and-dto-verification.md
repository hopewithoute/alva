Status: DONE

# Compile-Time Exposure & DTO Verification

## Parent

.scratch/alva-phase-10-security/PRD.md

## What to build

Implement the Action Exposure Verifier and Empty DTO Warning in the Alva extension's compile/transform phase. The compilation must halt with an error if a mapped action is not `public?: true`, and emit a warning if a mapped action produces no client-visible fields, preventing accidental domain leaks and useless payloads.

## Acceptance criteria

- [ ] A `Spark.Error.DslError` is raised at compile time if an event in `live_vue` maps to an action that is not `public?: true`.
- [ ] A `Logger.warning` is emitted at compile time if an event in `live_vue` maps to an action that returns a DTO with 0 public fields.
- [ ] The explicit exposure principle is enforced (no auto-expose functionality is added).
- [ ] New ExUnit tests verify these compilation rules by dynamically compiling test modules.

## Blocked by

None - can start immediately.
