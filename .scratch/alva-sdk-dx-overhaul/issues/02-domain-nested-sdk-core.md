Status: ready-for-agent

## Parent

.scratch/alva-sdk-dx-overhaul/PRD.md

## What to build

Rewrite the core SDK generator to output a single entry point `useAlva()`. 

The generated SDK should group capabilities into domain objects. For each action, generate an async function that correctly declares it returns `Promise<AlvaResult<Output>>` (fixing the existing TypeScript bug where it returns `AlvaResult`). For each signal, expose an `on_<signal>(cb)` function.

End-to-end slice: Migrate at least one component (e.g., `DemoChatPage.vue`) to use `const alva = useAlva()`, calling an action and listening to a signal via the new nested domain structure.

## Acceptance criteria

- [ ] `alva.codegen.ex` generates `useAlva()` instead of `useAlvaApi()`.
- [ ] Methods are grouped by domain (e.g., `alva.sales.create_order`).
- [ ] Action methods are strictly typed to return `Promise<...>`.
- [ ] Signals are mapped as `alva.domain.on_<signal>`.
- [ ] `DemoChatPage.vue` (or similar) is refactored and works end-to-end.

## Blocked by

None - can start immediately
