Status: done
Track: core-v2
PRD sequence: Migration step 1 - introduce the backend `subscription` registry and generated `AlvaSubscriptions`

## PRD alignment

This is the first primary v2 issue. It establishes the backend-owned host-app
registry for typed subscription capabilities so the frontend can activate named
capabilities without seeing raw topic strings.

## What to build

Build the foundational host-app registry that stores typed `subscription`
declarations and exposes them to TypeScript. In the current implementation,
this lands as resource-level `live_vue` `subscription ... do` declarations that
compile into the backend-owned registry. Update `mix alva.gen.ts` to output the
`AlvaSubscriptions` interface for declared capabilities. Signal end-to-end proof
continues in the dedicated signal pipeline issue.

## Acceptance criteria

- [x] Resource-level `subscription ... do` declarations parse and persist typed metadata.
- [x] The host-app subscription registry is available at runtime via `Alva.App.Info.registry/1`.
- [x] Codegen outputs `AlvaSubscriptions` types for declared subscription capabilities.

## Blocked by

- None - completed foundation slice
