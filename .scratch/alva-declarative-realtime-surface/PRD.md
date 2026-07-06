Status: ready-for-agent

# PRD - Alva Declarative Realtime Surface

## Problem Statement

Alva's realtime surface is currently too easy to misread. Collections, Signals, Route Subscriptions, command Event declarations, Ash PubSub Events, Topics, and legacy stream/subscription options are close enough in syntax that developers can accidentally mix transport scope, projection activation, command exposure, and occurrence matching.

The result is API debt: route-owned lists can fall back to shadow query state, Signals can look like raw PubSub subscriptions, `on:` can be mistaken for a command Event declaration, and old `subscriptions:` / `streams:` syntax can continue to appear even after the public model has moved to declarative `collections:`, `signals:`, and projection-keyed `route_subscriptions:`.

## Solution

Alva will expose one consistent declarative realtime surface:

- Resource declarations define reusable **Collections** and **Signals**.
- Command/read `event` declarations expose Vue-to-server calls and Collection Sources.
- Collection delta operations and Signal projections use `on:` to reference **PubSub Occurrence Keys**, normally the Ash action atom passed to `publish`.
- Page activation uses only `collections:`, `signals:`, and `route_subscriptions:`.
- `route_subscriptions:` is projection-keyed and owns Topic wiring only.
- Legacy declarative `subscriptions:`, `streams:`, nested collection `subscriptions:`, and nested collection `params:` fail loudly instead of silently falling back.

The developer should be able to trace a realtime feature from Ash action to page activation without translating between unrelated names:

```elixir
pub_sub do
  prefix("orders")
  publish(:create, ["all"], event: "order.created")
  publish(:fulfill, ["all"], event: "order.fulfilled")
end

live_vue do
  event :list_orders,
    name: "orders.list",
    action: :list

  event :fulfill_order,
    name: "orders.fulfill",
    action: :fulfill

  collection :sales_orders do
    source event: :list_orders, mode: :reset
    insert on: :create, at: 0, limit: -20
    update on: :fulfill, update_only: true
  end

  signal :order_fulfilled,
    name: "order.fulfilled",
    on: :fulfill
end
```

```elixir
use Alva.LiveView,
  domains: [MyApp.Sales],
  collections: [
    sales_orders: [source_input: :sales_order_source_input, reload_on: :route_change]
  ],
  signals: [:order_fulfilled],
  route_subscriptions: [
    {:sales_orders, :sales_order_topics},
    {:order_fulfilled, :order_fulfilled_topics}
  ]
```

## User Stories

1. As an Alva page author, I want a single declarative page activation surface, so that I do not have to choose between overlapping `streams`, `subscriptions`, `collections`, and `signals` APIs.
2. As an Alva page author, I want `collections:` to activate route-owned list projections, so that Vue receives server-owned list props rather than managing canonical list state.
3. As an Alva page author, I want `signals:` to activate semantic non-list projections, so that toast, progress, presence, and completion callbacks do not masquerade as list synchronization.
4. As an Alva page author, I want `route_subscriptions:` to wire Topics for already-active projections, so that Topic scope stays separate from projection behavior.
5. As an Alva page author, I want `route_subscriptions:` keys to use projection Declaration Keys for both Collections and Signals, so that page activation is consistent.
6. As an Alva page author, I want Signal activation to use atom Declaration Keys, so that I do not repeat browser event strings in page activation.
7. As a Vue developer, I want browser-facing names to live in `name: "..."`, so that `ashCall` and `ash.on` use stable exposed names while server wiring remains atom-based.
8. As a resource author, I want command/read `event` declarations to stay focused on Vue-to-server calls, so that command exposure is not confused with PubSub matching.
9. As a resource author, I want Collection `source event:` to reference a command/read Event Declaration Key, so that initial list loading uses the same projection and Auto-DTO contract as command reads.
10. As a resource author, I want Collection delta `on:` mappings to reference PubSub Occurrence Keys, so that insert/update/delete behavior reacts to Ash PubSub notifications rather than client command declarations.
11. As a resource author, I want Signal `on:` mappings to reference PubSub Occurrence Keys, so that Signals represent published occurrences rather than raw Topics or client commands.
12. As a resource author, I want `on:` to reject exposed browser names, so that transport/client naming cannot leak into server projection matching.
13. As a resource author, I want `on:` to reject concrete Topic strings, so that Topic scope remains page-owned under Route Subscriptions.
14. As a resource author, I want Projection Trigger semantics to match Ash PubSub `publish` identity, so that action-to-publication traceability stays Ash-native.
15. As a library maintainer, I want legacy declarative `subscriptions:` to fail loudly, so that old route subscription syntax cannot silently coexist with the new model.
16. As a library maintainer, I want legacy declarative `streams:` to fail loudly, so that Phoenix stream transport does not remain a public page activation concept.
17. As a library maintainer, I want nested collection `subscriptions:` to fail loudly, so that Topic wiring cannot hide inside projection activation.
18. As a library maintainer, I want nested collection `params:` to fail loudly, so that route params and Collection Source Input are not conflated.
19. As a library maintainer, I want invalid top-level activation keys to fail at compile-time where possible, so that developers catch unsupported DSL shapes before running the page.
20. As a library maintainer, I want duplicate `collections:` entries to fail at compile-time, so that each projection has one authoritative activation.
21. As a library maintainer, I want duplicate `signals:` entries to fail at compile-time, so that semantic callbacks cannot be activated twice by accident.
22. As a library maintainer, I want duplicate `route_subscriptions:` entries for the same projection to fail at compile-time, so that Topic overrides are unambiguous.
23. As a library maintainer, I want `route_subscriptions:` targets to reference active projections only, so that pages cannot subscribe infrastructure for inactive behavior.
24. As a library maintainer, I want invalid `route_subscriptions:` targets to fail at compile-time where the target set is declaration-known, so that mistakes are caught early.
25. As a page author, I want deterministic Route Subscription inference for simple static cases, so that ordinary pages do not repeat boilerplate Topic lists.
26. As a page author, I want inference to fail loudly for ambiguous publications, so that Alva never broadens realtime scope implicitly.
27. As a page author, I want inference to fail when Topic wiring depends on Page Scope, so that dynamic authorization and tenancy stay explicit.
28. As a page author, I want callback-based `route_subscriptions:` for dynamic scope, so that actor, tenant, route params, and permission checks can choose Topics.
29. As a page author, I want callbacks to support `[]` as an authoritative opt-out, so that a projection can stay active without subscribing to realtime Topics for a specific Page Scope.
30. As a page author, I want callback `nil` returns to fail loudly, so that missing returns do not behave like hidden opt-outs.
31. As a page author, I want explicit empty Topic lists to suppress inference, so that opt-out behavior is intentional and predictable.
32. As a page author, I want duplicate Topics to dedupe at the transport layer, so that harmless repeated Topic results do not cause extra socket subscriptions.
33. As a page author, I want multiple active projections resolving to the same Topic to share one transport subscription, so that Collection and Signal semantics remain independent while transport stays efficient.
34. As a page author, I want explicit `route_subscriptions:` Topic lists to be authoritative, so that Alva does not reject page-owned overrides simply because it cannot re-derive them from publication templates.
35. As a page author, I want imperative Alva helpers to remain available, so that branchy setup can escape the declarative surface without using old declarative syntax.
36. As a Phoenix developer, I want raw Phoenix PubSub to remain available, so that low-level flows outside Alva projections are still possible.
37. As a showcase maintainer, I want demo routes to use only the new declarative surface, so that examples teach the supported API rather than transition-era syntax.
38. As a showcase maintainer, I want route-owned lists to avoid client-owned query caches, so that the demo proves Collections own list lifecycle.
39. As a documentation reader, I want terminology to distinguish Action, Publication, Event, Topic, PubSub Occurrence Key, Projection Trigger, and Route Subscription, so that I can reason about realtime behavior without guessing.
40. As a future contributor, I want docs and tests to encode the final surface, so that compatibility code cannot reintroduce legacy behavior accidentally.

## Implementation Decisions

- Public declarative LiveView activation is allowlisted to `collections:`, `signals:`, and `route_subscriptions:`.
- Public activation uses keyword-form `use Alva.LiveView`; legacy tuple forms are not part of the supported surface.
- `collections:` activates Collection projections by atom Declaration Key.
- Collection activation entries are keyed and may use route-owned options such as `source_input:` and `reload_on:`.
- Collection activation does not accept nested `params:` or nested `subscriptions:`.
- `signals:` activates Signal projections by atom Declaration Key.
- Signal activation has no options until a concrete route-owned capability exists.
- `route_subscriptions:` is top-level and projection-keyed for both Collections and Signals.
- `route_subscriptions:` owns Topic wiring only; it does not replace Collection Sources or Projection Triggers.
- `route_subscriptions:` overrides are partial; projections not listed continue through deterministic inference.
- Explicit empty Topic lists are authoritative opt-outs and suppress inference for that projection.
- Callback-derived Route Subscriptions may return a binary Topic, a list of binary Topics, `[]`, or `{:ok, value}` wrapping those shapes.
- Callback-derived Route Subscriptions treat `[]` as dynamic opt-out and reject `nil`.
- Valid Topic lists may be normalized and deduped before subscribing.
- Multiple active projections resolving to the same Topic dedupe only at the transport layer; projection semantics remain independent.
- Explicit `route_subscriptions:` wiring is page-owned and authoritative; Alva validates target projection and topic-shape contract, not whether Topics can be re-derived.
- Deterministic inference is valid only when the final Topic set is static, finite, and derivable from projection/resource declarations alone.
- Deterministic inference fails when Topic wiring depends on Page Scope, callbacks, or ambiguous publication expansion.
- A projection trigger matching more than one publication is ambiguous even if the union of Topics would be static.
- A single publication may expand to multiple static Topics and remain deterministic.
- Publication topic callbacks are not eligible for deterministic inference.
- Invalid declarative activation shape fails at compile-time where the shape is declaration-known.
- Deterministic inference failures happen at activation time, when resource projection and publication matching are available.
- Duplicate Collection activations, duplicate Signal activations, and duplicate Route Subscription entries are declaration conflicts.
- `event` declarations are command/read exposure declarations with atom Declaration Keys and client-facing `name: "..."`.
- Collection `source event:` references a command/read Event Declaration Key because it executes a load path.
- Collection delta operations and Signal projections use `on:` for PubSub Occurrence Keys, normally the Ash action atom passed to `publish`.
- `on:` does not reference command Event Declaration Keys, exposed browser names, concrete Topics, or raw PubSub event strings.
- Signal declarations have atom Declaration Keys and client-facing `name: "..."`; Vue listens with `ash.on(exposed_name, callback)`.
- Imperative `Alva.LiveView` helpers and raw Phoenix PubSub remain escape hatches for branchy or low-level flows.
- Existing docs should use the glossary terms from `CONTEXT.md` and respect the page activation decision in the ADR.

## Testing Decisions

- The primary test seam is the `Alva.LiveView` activation contract, because it is the highest public boundary where page authors experience declarative activation success or failure.
- The secondary test seam is the resource DSL verifier/metadata seam for Collection and Signal declarations, because it is where command Event declarations, Collection Sources, and PubSub Occurrence Keys are resolved.
- Tests should assert external behavior and error contracts rather than internal helper names.
- Compile-time validation tests should cover unsupported activation keys, legacy tuple forms, duplicate projection activation, duplicate Route Subscription entries, invalid nested Collection opts, invalid Signal activation shapes, and Route Subscription targets that are not active projections.
- Activation-time tests should cover deterministic inference success, inference failure for ambiguous publications, inference failure for callback Topics, and explicit `route_subscriptions:` overrides.
- Dynamic callback tests should cover binary Topic returns, list returns, `{:ok, value}` returns, `[]` opt-out, `nil` failure, duplicate Topic normalization, and shared Topic transport dedupe.
- Resource projection tests should cover `source event:` resolving command/read Event Declaration Keys and `on:` resolving PubSub Occurrence Keys.
- Negative resource projection tests should cover `on:` values that look like exposed browser names, raw PubSub event strings, concrete Topics, or missing occurrence keys.
- Demo LiveView tests should verify that showcase routes no longer use legacy declarative `subscriptions:` or `streams:` and that route-owned lists remain on Collection props.
- Prior art includes existing `Alva.LiveView` tests, dispatcher/resource DSL tests, and commerce showcase LiveView tests.

## Out of Scope

- Redesigning the commerce showcase UI.
- Changing Ash resource business rules unrelated to realtime projection wiring.
- Replacing Phoenix PubSub or Ash.Notifier.PubSub.
- Removing imperative Alva helpers or raw Phoenix PubSub escape hatches.
- Designing a new authorization system; callbacks may call existing permission checks such as Ash policy checks.
- Adding Signal activation options before a concrete route-owned capability justifies them.
- Changing Vue `ashCall` or `ash.on` exposed-name semantics beyond keeping them aligned with generated types.
- Implementing route-owned support message collection behavior unless needed by a later showcase issue.
- Providing backward-compatible legacy declarative syntax after this PRD is implemented.

## Further Notes

- This PRD formalizes decisions captured in the glossary, phase-9 realtime model, and page activation ADR.
- The terminology intentionally separates Action, Publication, Event, Topic, PubSub Occurrence Key, Projection Trigger, Route Subscription, Collection, and Signal.
- The expected migration posture is fail-loud, not transitional compatibility.
- The most important developer experience outcome is that resource definitions, projection activation, and route subscription wiring each answer one question:
- Resource projection answers what can happen to page-visible state when an occurrence arrives.
- Route Subscription answers which Topics can deliver occurrences to this page.
- Command Event declaration answers which Vue-to-server call can be made immediately.
