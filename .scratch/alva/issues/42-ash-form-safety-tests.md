Status: ready-for-agent

## Parent
`docs/prd.md` (Phase 8 - Forms Integration)

## What to build
Enhance and verify the `ashForm` Vue composable's debounce mechanism to guarantee immunity to race conditions. Prove (or adjust if needed) that parallel debounced typings (`validateEvent`), intersecting with full `submitEvent` actions, do not result in stale promises overwriting the reactive `errors` state. Add Vitest tests for the Vue client's `ashForm.ts`.

## Acceptance criteria
- [ ] `ashForm.ts` reliably cancels pending debounce logic upon full submission or newer validations.
- [ ] Vitest spec tests are added to `alva/assets/js/ashForm.spec.ts` mocking the `api.call` response and asserting correctness during race-condition scenarios.
- [ ] No regression occurs in `ashForm`'s existing error application logic.

## Blocked by
- 41-form-validation-dispatch.md
