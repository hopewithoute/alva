Status: done

# Remove Stream Surface And Migrate Route-Owned Lists To Collections

## What to build

Remove Stream from Alva's public surface so route-owned list state is modeled only as Collections, while non-projection flows fall back to raw Phoenix PubSub escape hatches. This slice should replace remaining Stream-based showcase behavior with Collection-based behavior, remove imperative Stream activation and the Stream DSL from Alva, and prove that route-owned list state such as support messages still behaves correctly through Collection sources, realtime deltas, and route-owned topic scope.

## Acceptance criteria

- [x] Alva no longer exposes `activate_stream/2` or a public `stream` DSL.
- [x] Route-owned list behavior that still depends on Stream semantics is migrated to Collection semantics end to end.
- [x] Compile-time failures clearly reject legacy Stream-based Alva surface usage during development.
- [x] Raw Phoenix PubSub remains the only escape hatch for realtime flows outside the Alva projection model.
- [x] Tests cover Collection-based replacement behavior for the migrated route-owned list surfaces and failure of removed Stream APIs.

## Blocked by

- `.scratch/alva-host-app-registry-migration/issues/02-activate-collections-and-signals-without-page-domains.md`
