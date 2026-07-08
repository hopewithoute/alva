# Consolidate DSL introspection into Alva.Registry
Status: ready-for-agent

## What to build
Consolidate the spread of introspection modules (`App.Info`, `Domain.Info`, `Resource.Info`) into a single deep module called `Alva.Registry`.

This registry should traverse the Spark DSLs internally via a private adapter, completely decoupling the public API from Spark internals. It should maintain the current lazy-loading behavior (aggregated at runtime) and cache the final registry map in `:persistent_term`.

## Acceptance criteria
- [ ] `Alva.Registry` module is created and provides a single API for fetching the aggregated event, subscription, and signal maps across the host app.
- [ ] Existing `Info` modules (`App.Info`, `Domain.Info`, `Resource.Info`) are removed or subsumed.
- [ ] Spark DSL extraction (`Spark.Dsl.Extension.get_persisted`, etc.) is encapsulated behind a private adapter within `Alva.Registry`.
- [ ] Lazy-loading and `:persistent_term` caching are retained and properly moved into the new module.

## Blocked by
None - can start immediately
