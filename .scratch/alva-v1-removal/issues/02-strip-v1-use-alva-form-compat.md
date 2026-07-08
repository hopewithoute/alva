Status: done

## What to build

Strip V1 backward compatibility from the `useAlvaForm` signature and internals. 

Currently, `useAlvaForm` includes an unused `api` parameter as its first argument to match the V1 API shape. It also exposes manual wrapper refs for `loading`, `errors`, and `values`, as well as a stubbed `validate()` function. This slice removes these compatibility layers so that `useAlvaForm` directly exposes the native `live_vue` behavior.

## Acceptance criteria

- [ ] Remove the unused `api` parameter from `useAlvaForm.ts`, shifting arguments so that `submitEvent` is first.
- [ ] Remove the stubbed `validate()` function.
- [ ] Remove the `loading`, `errors`, and `values` fallback properties (exposing only what `live_vue` returns).
- [ ] Update `alva/assets/js/useAlvaForm.spec.ts` to reflect the new signature and test only the required logic.

## Blocked by

None - can start immediately
