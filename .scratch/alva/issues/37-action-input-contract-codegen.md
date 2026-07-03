Status: ready-for-agent

## Parent
`docs/prd.md` (Phase 7 - TypeScript Codegen)

## What to build
Enhance the codegen logic to introspect Ash Actions (create, update, generic) and map their accepted arguments into TypeScript input contracts. Update `events.ts` so that the `input:` property of each event string maps directly to an object shape requiring the mandatory fields and allowing the optional fields as defined by the underlying Ash Action. 

## Acceptance criteria
- [ ] Action arguments are translated to TypeScript properties.
- [ ] Optional arguments and arguments with default values are marked as optional (`?:`) in TypeScript.
- [ ] `events.ts` enforces the strict input shapes for all mutation events.

## Blocked by
- `.scratch/alva/issues/36-typemapper-and-dto-codegen.md`
