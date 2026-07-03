Status: done

## Parent
`docs/prd.md` (Phase 7 - TypeScript Codegen)

## What to build
Extend the TypeMapper to handle complex Ash types including Embedded Resources, Enums, and Unions (reproducing the introspection logic of `ash_typescript` without the dependency). Furthermore, for any event configured with `enable_filter: true`, vendor the logic to generate the Ash Filter AST TypeScript shapes, enabling completely type-safe complex queries from the Vue datatable components.

## Acceptance criteria
- [x] Embedded resources, Unions, and Enums generate accurate nested interfaces or union string literals.
- [x] `enable_filter: true` causes the event input to accept a strictly typed `filter` property (based on the resource's fields).
- [x] Ash Filter AST logic (e.g. `and`, `or`, `ilike`) is accurately exported to `types.ts`.

## Blocked by
- `.scratch/alva/issues/37-action-input-contract-codegen.md`
