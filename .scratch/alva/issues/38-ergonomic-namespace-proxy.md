Status: ready-for-agent

## Parent
`docs/prd.md` (Phase 7 - TypeScript Codegen)

## What to build
Build a generator that reads the parsed `AlvaEvents` and creates an ergonomic namespace proxy wrapper. The wrapper should recursively convert string paths like `"students.list"` into callable functions on an object tree, e.g., `api.students.list()`. Generate this code and export it within the `client.ts` file so Vue components can invoke the backend API using object dot-notation with full autocomplete.

## Acceptance criteria
- [ ] A proxy or explicitly generated object tree is built corresponding to the domain/resource namespaces.
- [ ] Dot-notation invocation (e.g. `api.domain.action(input)`) accurately triggers `ashCall("domain.action", input)`.
- [ ] Autocomplete and strict type-checking work natively in IDEs for the namespace API.

## Blocked by
- `.scratch/alva/issues/37-action-input-contract-codegen.md`
