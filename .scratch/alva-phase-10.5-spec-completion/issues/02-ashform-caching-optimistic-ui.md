## What to build

Update the `ashForm` Vue composable (`alva/assets/js/ashForm.ts`) to include an in-memory database validation cache and explicit Optimistic UI support. 
The cache must be scoped to the specific form instance lifecycle (clearing when the component unmounts) to prevent spamming the database with identical validation requests while typing.
Optimistic UI must be implemented via an explicit `onOptimisticSubmit` developer callback that allows the developer to instantly mutate client-side state and handles rolling back if the server returns an error.

## Acceptance criteria

- [x] `ashForm` implements an instance-scoped in-memory cache for server-side validation checks.
- [x] The cache correctly prevents identical validation network requests (e.g. backspacing and retyping).
- [x] The cache explicitly clears when the component unmounts (memory leak prevention).
- [x] `ashForm` accepts an `onOptimisticSubmit: (formData) => rollbackFn` configuration callback.
- [x] When submitted, `ashForm` invokes `onOptimisticSubmit` before awaiting the server response.
- [x] If the server command fails (or throws), the `rollbackFn` is executed to revert the optimistic local state.
- [x] Validation and submission tests are updated/written to cover these features.

## Blocked by

None - can start immediately
