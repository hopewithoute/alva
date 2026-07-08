Status: done

## What to build

Update the Elixir backend macro `Alva.LiveView` to actively reject legacy V1 activation keys with compile-time errors. 

The declarative V2 page activation model exclusively uses `subscriptions:` and `commands:`. The older keys (`collections:`, `signals:`, `route_subscriptions:`, `page_events:`, and `page_state:`) were kept as "legacy compatibility surfaces" in the allowlist. This task removes them and forces consumers to migrate.

## Acceptance criteria

- [ ] Remove `collections:`, `signals:`, `route_subscriptions:`, `page_events:`, and `page_state:` from the allowlist in `alva/lib/alva/live_view.ex`.
- [ ] Intercept the usage of these removed keys and throw clear compile-time errors instructing the user that these keys were removed in V2.
- [ ] Delete any internal validation helper functions that were exclusively used for these legacy keys.
- [ ] Run Elixir tests and verify the removal completes successfully.

## Blocked by

None - can start immediately
