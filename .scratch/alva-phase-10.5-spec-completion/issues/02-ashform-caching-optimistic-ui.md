## What to build

Update the `ashForm` Vue composable (`alva/assets/js/ashForm.ts`) to include an in-memory database validation cache and explicit Optimistic UI support. 
The cache must be scoped to the specific form instance lifecycle (clearing when the component unmounts) to prevent spamming the database with identical validation requests while typing.
Optimistic UI must be implemented via an explicit `onOptimisticSubmit` developer callback that allows the developer to instantly mutate client-side state and handles rolling back if the server returns an error.

## Acceptance criteria

- [ ] `ashForm` implements an instance-scoped in-memory cache for server-side validation checks.
- [ ] Submitting the same field value multiple times (e.g. backspacing and retyping) uses the cache instead of querying the DB.
- [ ] `ashForm` accepts an `onOptimisticSubmit: (formData) => rollbackFn` configuration callback.
- [ ] When submitted, `ashForm` invokes `onOptimisticSubmit` before awaiting the server response.
- [ ] If the server command fails, the rollback function is executed to revert the optimistic local state.

## Blocked by

None - can start immediately
