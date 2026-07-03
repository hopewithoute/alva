Status: ready-for-agent

# PRD — Alva Phase 9 Realtime: Commands, Streams, Signals

## Problem Statement

Alva currently has realtime concepts that are too easy to confuse. Command replies, server-pushed PubSub notifications, Phoenix stream mutations, LiveVue stream diffs, and Vue-side callback handling are all close enough that implementation can accidentally create competing list update paths.

The user needs Phase 9 to make chat, feed, notification, and multi-window list updates first-class without making Vue manually reconcile canonical collections. A mutation in one window should update the same route collection in another window through the LiveView/LiveVue stream path, while the initiating caller still receives immediate command feedback.

## Solution

Phase 9 introduces a clear communication model:

1. Commands are Vue-to-server request/reply interactions.
2. Route Subscriptions define which concrete PubSub topics a LiveView socket listens to.
3. Streams are resource-level collection projections triggered by Ash PubSub published event names through `on:`.
4. Route Collections are initialized and mutated server-side with Phoenix stream operations, then delivered to Vue through LiveVue 1.x stream diffs.
5. Stream Queries are page-level bindings that apply paginated or filtered command results to active streams using server-side stream operations.
6. Signals are semantic non-collection callbacks for async progress, completion, presence, typing, toast-like notifications, and other non-canonical-list occurrences.

Resource DSL declares reusable Resource Projections. LiveView pages choose Route Subscriptions and activate Page Projections. Vue sends Commands, renders LiveVue stream props for Route Collections, and handles Signals through callbacks only when the occurrence is not canonical collection state.

## User Stories

1. As a Phoenix/Ash developer, I want command events to remain request/reply interactions, so that forms and buttons receive immediate success, validation, and error feedback.
2. As a Vue developer, I want a create command to return a stable command result, so that I can close dialogs, clear forms, or show field errors without waiting for a broadcast.
3. As a user with two browser windows open, I want a record created in one window to appear in the other, so that both windows stay consistent.
4. As a developer building a list page, I want collection changes to flow through LiveView streams and LiveVue stream diffs, so that Vue does not maintain a second canonical list reconciler.
5. As a developer building a chat page, I want new messages to update every subscribed room window, so that realtime chat works without manual append logic in Vue.
6. As a developer building a feed page, I want insert/update/delete mappings to be explicit, so that server occurrences are projected into the correct collection operation.
7. As a developer building a notification bar, I want a server occurrence to be usable as a Signal, so that I can show a toast without treating it as a collection update.
8. As a developer building a page-specific view, I want the same server occurrence to be streamable on one page and signaled on another, so that UI projections match page needs.
9. As a developer working with tenant or room scopes, I want Route Subscriptions to stay page-level, so that topic selection can depend on route params, actor, tenant, and session.
10. As a developer who prefers raw Phoenix primitives, I want raw Phoenix PubSub subscription to remain valid, so that Alva does not hide the underlying transport.
11. As a developer who wants consistent examples, I want a thin Alva route subscription helper, so that common route subscription code reads consistently.
12. As a developer defining a resource contract, I want Stream Blocks to use `on:` mappings, so that it is clear they reference Ash PubSub published event names rather than Alva command events.
13. As a developer defining a resource contract, I want command `event` declarations to stay distinct from stream `on:` triggers, so that request/reply and publish/subscribe language does not blur.
14. As a developer defining a stream, I want the stream name to be domain-unique, so that page activation is unambiguous.
15. As a developer defining a Signal, I want signal names to be domain-unique, so that TypeScript callback payloads have a stable contract.
16. As a Vue developer, I want route collections to arrive as LiveVue stream props, so that I render canonical collection state without local append/delete code.
17. As a Vue developer, I want `ashQuery` to remain for ad hoc reads rather than route-owned collection sync, so that query code does not become a hidden stream engine.
18. As a developer implementing pagination, I want paginated reads to be modeled as normal command events, so that load-more is not a special resource-level concept.
19. As a developer implementing pagination on a route collection, I want a Stream Query binding to apply command results to an active stream, so that older/newer items are inserted by the server stream operation.
20. As a developer implementing filtered collection refresh, I want a Stream Query binding to reset an active stream, so that filter/search results replace the route collection consistently.
21. As a developer handling async jobs, I want job progress and completion to be Signals, so that long-running workflows can callback to Vue without pretending to be collections.
22. As a developer handling presence or typing indicators, I want those occurrences to be Signals, so that ephemeral state does not pollute route collections.
23. As a package maintainer, I want compile-time verification for stream and signal names, so that contract mistakes fail early.
24. As a package maintainer, I want tests around page projection behavior, so that the same occurrence can be projected differently by different pages without global coupling.
25. As a package maintainer, I want old Vue-side list reconciliation paths removed or deprecated, so that Phase 9 has one canonical collection sync model.

## Implementation Decisions

- Commands remain the existing Alva command event model. A command event maps a Vue-called event string to an Ash action and returns a normalized `LiveResult`.
- `event` remains reserved for command declarations. Stream and Signal projections must not use `event` to refer to Ash PubSub published occurrences.
- Stream Blocks are resource-level Resource Projections. They declare a domain-unique stream name and explicit insert/update/delete mappings with `on:` values.
- The `on:` value references an Ash PubSub published event name.
- Stream Blocks do not define pagination or load-more behavior.
- Signals are resource-level Resource Projections for semantic non-collection callbacks. Signal names are domain-unique.
- Route Subscriptions are page/socket-level and may be expressed through raw Phoenix PubSub or a thin Alva helper.
- Page Projections activate selected Resource Projections for a LiveView page. Activation is page-scoped because the same occurrence may be a Stream on one page, a Signal on another, and ignored elsewhere.
- Route Collections are server-owned collections. They are initialized and mutated using Phoenix stream operations, and LiveVue 1.x delivers stream diffs to Vue props.
- Stream Queries are page-level bindings from a command/read event to an active Route Collection. They apply command results to the server stream using append, prepend, reset, and limit semantics.
- Vue does not manually append, replace, delete, or dedupe records for stream-owned Route Collections.
- `ashQuery` remains for ad hoc reads/searches that are not owned by a route stream. It should not be the primary realtime collection sync mechanism.
- `ash.on` remains for Signals and should not be used to maintain canonical lists.
- The resource extension should grow new entities for Stream and Signal projections while keeping the existing command Event entity.
- The domain transformer should persist separate lookup maps for commands, streams, and signals.
- The verifier should reject duplicate command event names, duplicate stream names, and duplicate signal names within a domain.
- The verifier should ensure stream and signal projection triggers are structurally valid. If Ash PubSub publication introspection is reliable in the installed Ash version, it should also verify that `on:` references a known published event name.
- The LiveView integration should route incoming Ash notifications through page-activated projections, not through a generic always-pushed `ash_notification` event.
- The current generic `ash_notification` push is not the final Signal contract.
- Current result strategy language around arbitrary `stream_insert` and `stream_delete` should be treated as legacy until it is reconciled with Page Projection and Route Collection ownership.
- TypeScript codegen should eventually generate separate types for command events and signals. Stream prop typing should align with LiveVue 1.x stream support rather than a custom Vue-side accumulator.

## Testing Decisions

- Tests should verify externally visible contracts: DSL compilation, verification errors, LiveView page projection behavior, command reply behavior, stream mutation behavior, and Signal callback behavior.
- DSL tests should cover successful stream and signal declarations, duplicate stream names, duplicate signal names, and distinct command/stream/signal namespaces.
- Domain transformer tests should assert that command, stream, and signal lookup maps are persisted separately and are discoverable through Info modules.
- Verifier tests should assert that invalid duplicate names fail at compile time with actionable errors.
- LiveView integration tests should simulate an Ash notification received by a subscribed page and verify that an active Stream projection mutates the configured Phoenix stream.
- LiveView integration tests should verify that an inactive Stream projection does not mutate a page that did not activate it.
- LiveView integration tests should verify that an active Signal projection pushes the semantic signal name and DTO payload rather than a generic notification envelope.
- Stream Query tests should verify prepend, append, reset, and pagination metadata behavior without requiring Vue-side list reconciliation.
- Frontend tests should verify that `ashQuery` no longer owns stream insert/delete event reconciliation for route-owned collections.
- Frontend tests should verify that `ash.on` is used for Signal callbacks, not canonical collection updates.
- Prior art exists in current dispatcher, resource verifier, domain transformer, LiveView, result, `ashQuery`, and `useAlvaApi` tests.

## Out of Scope

- Full public package documentation and Hex release polish.
- A complete chat application beyond the minimal example needed to prove Phase 9 behavior.
- Replacing Ash PubSub itself or introducing a custom channel layer.
- Making Vue the source of truth for canonical collection reconciliation.
- Building a GraphQL-style dynamic field selection system.
- Client-side manual dedupe, append, update, or delete logic for route-owned collections.
- A new frontend state manager.
- Broad redesign of unrelated command dispatch, form validation, upload, or codegen behavior.

## Further Notes

- This PRD supersedes the older “streamInsertEvent / streamDeleteEvent as ashQuery options” mental model for route-owned collections.
- The existing local demo dependency may lag behind LiveVue 1.x stream support; implementation should target LiveVue 1.x behavior.
- The existing broad project PRD still describes Phase 9 at a high level. This PRD sharpens Phase 9 with the glossary and ADR decisions made during the grill session.
- ADR 0002 records the command/stream/signal split and should guide implementation.
- The first implementation slice should likely be DSL shape, Info accessors, domain persistence, and compile-time verification before runtime behavior.
