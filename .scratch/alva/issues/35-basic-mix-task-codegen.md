Status: done

## Parent
`docs/prd.md` (Phase 7 - TypeScript Codegen)

## What to build
Create a basic Mix task (`mix alva.codegen`) that serves as the entry point for TypeScript generation. The task must traverse all Ash resources in the application, detect the `Alva.Resource` extension, parse the `live_vue` events, and generate two basic files: an `events.ts` file containing a static mapping of all event strings with `any` input/output types, and a `client.ts` bootstrapper to bind the event map to the Vue client SDK. Output must be safely isolated to a default directory like `assets/js/alva/`.

## Acceptance criteria
- [ ] `mix alva.codegen` task exists and can be executed without errors.
- [ ] Discovers all `event` entities defined in `live_vue do ... end` blocks across resources.
- [ ] Generates `events.ts` exporting an `AlvaEvents` type map.
- [ ] Generates `client.ts` that exports a configured API client.

## Blocked by
- None - can start immediately
