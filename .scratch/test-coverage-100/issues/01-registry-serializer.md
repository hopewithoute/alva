Status: ready-for-agent

## What to build
Implement 100% test coverage for the introspection logic in `Alva.Registry` and object serialization in `Alva.Serializer`. This slice focuses on validating compile-time macros, checking domain uniqueness, mapping Ash records to maps, and ensuring any remaining V1 legacy codepaths in these modules are identified and removed if unused.

## Acceptance criteria
- [ ] 100% test coverage on `lib/alva/registry.ex`.
- [ ] 100% test coverage on `lib/alva/serializer.ex`.
- [ ] Check and completely scrub any V1 properties or unused legacy surfaces from these modules.

## Blocked by
None - can start immediately
