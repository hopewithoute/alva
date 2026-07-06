Status: completed

## What to build

Build three isolated example routes within the `alva_demo` application to clearly demonstrate Alva's realtime primitives (Commands, Streams, Signals) in action. 
These should be separate pages (e.g. `/demo/chat`, `/demo/notifications`, `/demo/load-more`) so that developers can study one primitive pattern at a time without tangling boilerplate.

## Acceptance criteria

- [x] A standalone Chat demo route is built, demonstrating Streams (appending messages to a collection in realtime).
- [x] A standalone Notifications demo route is built, demonstrating Signals (triggering toast/alerts for non-collection occurrences).
- [x] A standalone Load-More demo route is built, demonstrating `bind_stream_query` (fetching paginated data and appending it to an existing Stream collection).
- [x] Each route is accessible from the demo app's main navigation.
- [x] The examples include clear Vue components with no extraneous business logic.

## Blocked by

None - can start immediately

## Comments

- The load-more example uses the current route-owned collection refresh path (`source_input` + `reload_on: :route_change`) instead of reintroducing the removed `bind_stream_query` bridge. This matches the more recent repo guidance in `docs/alva-demo-api-surface.md` and ADR `0002-realtime-command-stream-signal-split`.
