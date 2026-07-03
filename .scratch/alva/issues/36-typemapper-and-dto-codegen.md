Status: done

## Parent
`docs/prd.md` (Phase 7 - TypeScript Codegen)

## What to build
Implement a base `TypeMapper` module to convert basic Ash primitive types (string, integer, boolean) to TypeScript scalar types. Extend the code generator to introspect the `public_fields` (attributes, calculations, relationships, aggregates) of each exposed Ash resource (replicating the Auto-DTO behavior). Generate a `types.ts` file containing TypeScript interfaces matching these shapes, and update `events.ts` so that the `output` field points to `LiveResult<MyResourceDto>` instead of `any`.

## Acceptance criteria
- [ ] Primitive types are mapped correctly to TS strings, numbers, and booleans.
- [ ] `types.ts` is generated with `interface` declarations for all exposed resources.
- [ ] Only public fields (as determined by Ash API logic) are present in the interfaces.
- [ ] `events.ts` leverages these generated interfaces for its output contracts.

## Blocked by
- `.scratch/alva/issues/35-basic-mix-task-codegen.md`
