Status: done

## What to build
Implement 100% test coverage for the event dispatching mechanisms in `Alva.Dispatcher` and the core utility functions such as `alva/error.ex`, `alva/result.ex`, and `alva/resource/verifiers`. This slice focuses on edge cases in dispatching, unsupported uploads, and standard error handling, while removing any dead code or V1 artifacts discovered.

## Acceptance criteria
- [ ] 100% test coverage on `lib/alva/error.ex`, `lib/alva/result.ex`, and all `verifiers`.
- [ ] Check and completely scrub any V1 properties or unused legacy surfaces from these modules.

## Blocked by
None - can start immediately
