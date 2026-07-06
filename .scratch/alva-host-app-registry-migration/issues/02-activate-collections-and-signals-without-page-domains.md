Status: done

# Activate Collections And Signals Without Page Domains

## What to build

Move page-facing projection activation onto the same Host App Registry Boundary so `use Alva.LiveView` activates Collections and Signals by application-wide declaration keys without `domains:`. This slice should prove that route-owned Collection loads, Signal delivery, upload setup, and route subscription wiring all resolve through host app context, while host-app compile-time verification catches application-wide collisions for page-facing projection keys and exposed Signal names.

## Acceptance criteria

- [x] `use Alva.LiveView` activates Collections and Signals without a `domains:` option.
- [x] Collection loading, Signal activation, route subscription wiring, and upload setup resolve through host app context rather than page-scoped Domain lists.
- [x] Host-app compile-time verification fails when page-facing projection keys or exposed Signal names collide application-wide.
- [x] Legacy page-scoped `domains:` activation fails loudly at compile time without a deprecation shim.
- [x] Tests cover declarative Collection and Signal activation through the host app registry, duplicate projection failure, and invalid `domains:` usage.

## Blocked by

- `.scratch/alva-host-app-registry-migration/issues/01-route-commands-through-host-app-registry-boundary.md`
