Status: done

## What to build
Create the integration test suite for the LiveView lifecycle, specifically focusing on `on_mount` hooks, `attach_event_hook` logic, and all `handle_info` message processors in `Alva.LiveView`. This includes simulating PubSub subscription events reaching the LiveView socket and removing any remaining V1 page state properties or legacy behaviors.

## Acceptance criteria
- [x] Substantial test coverage covering all `handle_info` cases in `lib/alva/live_view.ex`.
- [x] Complete test coverage for the `on_mount` lifecycle hooks and subscription setup.
- [x] Check and completely scrub any V1 properties (like old `page_state`, `collections`, `signals` behaviors) from the LiveView event lifecycle if they are dead code.

## Blocked by
- .scratch/test-coverage-100/issues/01-registry-serializer.md
- .scratch/test-coverage-100/issues/02-dispatcher-core.md
