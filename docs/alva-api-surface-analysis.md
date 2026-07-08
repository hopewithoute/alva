# Alva API Surface Analysis (Historical Snapshot)

## Purpose

This document maps the actual Alva API surface in the current repository so we
can write a complete guide from repo truth instead of from older design notes.

It is now best treated as a historical analysis and compatibility reference.
For the primary V2 user-facing path, start with
`docs/alva-demo-api-surface.md` and ADR 0009 instead of this document.

It focuses on four questions:

1. What is public today?
2. What is internal or compatibility-only?
3. Where has documentation drifted from the code?
4. What guide structure would cover the whole surface without mixing layers?

## Scope And Assumptions

- Scope is the current repository state on `2026-07-07`.
- "Public API surface" means surfaces a host app or Vue app is expected to call
  or declare directly.
- Tests are treated as contract evidence when docs and implementation disagree.
- ADRs remain useful for vocabulary and intent, but they are not automatically
  the source of truth for current syntax.

## The Actual Public Surface

Alva currently exposes five distinct surfaces. Guide content should mirror
these boundaries instead of documenting Alva as one flat API.

### 1. Resource DSL Surface

This is the Ash resource extension used to declare what a resource exposes to
the LiveView and Vue boundary.

Primary entrypoint:

- `extensions: [Alva.Resource]` on `use Ash.Resource`

Public `live_vue` entities:

- `event`
- `collection`
- `signal`

Important details:

- `event` is the browser-facing command/read declaration. It uses an atom
  declaration key plus a globally exposed string `name`.
- `collection` is the public list projection surface. It requires an explicit
  `source event: ...` declaration and may declare `insert`, `update`, and
  `delete` operations triggered by PubSub occurrence keys.
- `signal` is the semantic realtime callback surface. It uses an atom
  declaration key for activation and a string `name` for Vue delivery.
- `stream` still exists in the DSL only as a legacy shim so compilation can
  fail loudly with a migration error. It is not part of the supported surface.

Documentation consequences:

- The guide should teach declaration keys and exposed names as separate things.
- The guide should explain that collection `source event:` references an Alva
  event declaration key, while collection/signal `on:` references a PubSub
  occurrence key.
- The guide should explicitly mark `stream` as rejected legacy syntax, not as a
  second realtime option.

### 2. Domain And Host-App Registry Surface

This is the compile-time/runtime registry layer that resolves application-wide
command, collection, and signal identity.

Primary entrypoints:

- `extensions: [Alva.Domain]` on `use Ash.Domain`
- host app `ash_domains`
- `otp_app`-keyed host app registry resolution

Current behavior:

- Alva no longer expects page-scoped `domains:` when a LiveView activates
  projections.
- The host app registry is built from the consuming app's configured
  `ash_domains`.
- Application-wide uniqueness is enforced for:
  - exposed event names
  - collection keys
  - signal keys
  - signal exposed names

Documentation consequences:

- The guide should show `Alva.Domain` as required setup, not as optional
  introspection sugar.
- The guide should explain why collection and signal keys are application-wide.
- The guide should clearly state that page-scoped `domains:` is removed from
  the supported public activation surface.

### 3. LiveView Page Activation Surface

This is the main route-level API surface for turning resource capabilities into
active page behavior.

Primary entrypoint:

- `use Alva.LiveView, ...`

Supported declarative top-level keys today:

- `collections:`
- `signals:`
- `route_subscriptions:`
- `page_events:`
- `page_state:`

Important rules from implementation and tests:

- `use Alva.LiveView` must use keyword-form declarative activation.
- `domains:` is rejected.
- top-level `streams:` is rejected.
- top-level `subscriptions:` is rejected.
- declarative collection opts only allow:
  - `source_input:`
  - `reload_on:`
- declarative collection `params:` is rejected in favor of `source_input:`.
- nested collection `subscriptions:` is rejected in favor of top-level
  `route_subscriptions:`.
- `signals:` accepts atom declaration keys only, not browser-facing strings.
- duplicate entries fail loudly across `collections:`, `signals:`,
  `route_subscriptions:`, and `page_events:`.
- `collections:` and `signals:` share one projection namespace on the page.

Route subscription contract:

- Target keys must reference already-activated projections on the same page.
- Each entry is `{projection_key, topics}`.
- `topics` may be:
  - a binary topic
  - a list of binary topics
  - a callback atom
- callback results may be:
  - binary topic
  - list of binary topics
  - `[]`
  - `{:ok, binary | [binary] | []}`
- `[]` is an authoritative opt-out.
- `nil` is invalid and should fail loudly.
- callback-driven subscriptions participate in route lifecycle updates and topic
  diffing.

Page events contract:

- `page_events:` entries are `{event_name, callback}` or
  `{event_name, callback, input_types}`.
- `event_name` is a browser-facing string.
- `callback` is a local LiveView callback atom.
- optional `input_types` is an Elixir-native map such as
  `%{conversation_id: :string}`.
- callbacks must return `{:reply, map, socket}`.
- page event names may not collide with host app dispatcher events.

Page state contract:

- `page_state:` is a single local callback atom.
- callback returns a map of page-owned state for Vue consumption.
- it is route-lifecycle aware, so it re-syncs after route changes handled by
  Alva.

Imperative helpers still exposed by `Alva.LiveView`:

- `collection/3`
- `reload_collection/3`
- `activate_signal/2`
- `route_subscriptions/1`
- `route_params/1`
- `projection_active?/3`

Compatibility note:

- Manual `collection/3` and `reload_collection/3` still accept `params:` as an
  alias for `source_input:` at runtime.
- Declarative activation does not accept that alias.
- This should be documented as compatibility behavior, not as the preferred
  public contract.

Documentation consequences:

- The guide should separate declarative activation from imperative helper usage.
- The guide should document `page_events:` and `page_state:` as first-class
  current surface, not as future work.
- The guide should include a fail-loud reference page for rejected legacy
  shapes because those errors are part of the user-facing authoring experience.

### 4. Dispatcher Result Contract

This is the command/read execution surface that backs both direct dispatch and
LiveView event handling.

Primary entrypoint:

- `Alva.Dispatcher.dispatch/3`

Current capabilities:

- resolves events application-wide from the host app registry
- accepts `otp_app:` directly or derives it from `socket.endpoint`
- injects `actor` and `tenant` from `socket.assigns`
- supports `:read`, `:create`, `:update`, `:destroy`, and `:action`
- supports `lookup`-based reads and updates
- strips metadata from returned records by default
- preserves selected metadata only when declared via `expose_metadata`
- emits telemetry on dispatch
- handles Ash file upload arguments by consuming LiveView uploads and copying
  entries to persisted temp files before action execution

Result shape:

- success: `%{ok: true, data: ...}` or `%{ok: true, data: ..., meta: ...}`
- error: `%{ok: false, error: ...}`

Additional payload behavior:

- page reads with Ash pagination attach pagination metadata under `meta`
- permission-like fields prefixed with `can_` are moved under `meta._permissions`
- errors are normalized through `Alva.Error`

Documentation consequences:

- The guide should explain the normalized result shape once and reuse it across
  command docs, page events docs, and client API docs.
- Upload docs should explain that Ash actions still define file arguments, but
  Alva handles LiveView upload consumption and temporary file persistence.
- If `Alva.Dispatcher.dispatch/3` is considered advanced host-app surface
  rather than normal day-to-day API, the guide should label it that way.

### 5. Vue Client Surface

This is the published JS package surface under `alva/assets/js/index.ts`.

Exports:

- `useAlvaApi`
- `useAlvaForm`
- `useAlvaQuery`
- `useAlvaUpload`
- `useAlvaEvent`
- `provideAlvaPageState`
- `useAlvaPageState`

#### `useAlvaApi`

Current returned API:

- `call(event, payload, options?)`
- `on(signal_name, callback)`

Important detail:

- The returned object exposes `call(...)` as the command entrypoint.
- The public surface is now internally and externally aligned on `call`.

#### `useAlvaQuery`

Current role:

- ad hoc read/query helper for data that is not owned by an Alva Collection

Important limitation:

- it does not perform collection reconciliation from stream diffs
- it should not be documented as the route-owned list mechanism

#### `useAlvaForm`

Current role:

- form state
- debounced server validation
- validation result caching
- optimistic submit rollback hooks
- upload reference injection

Important detail:

- the implementation is server-validation-first
- there is no current generated client-side validation schema surface

#### `useAlvaUpload`

Current role:

- wraps LiveView upload lifecycle from Vue
- tracks files, errors, and aggregate progress
- exposes `getFileReferences()` for Ash file arguments
- exposes `dispatch(...)` to wait for upload completion before running command
  code

Important host-app contract:

- the matching upload config must be passed to the LiveVue component, for
  example `media={@uploads.media}`
- if not, `useAlvaUpload("media")` degrades into a warning/error helper

#### `useAlvaEvent`

Current role:

- thin loading/error wrapper around `useAlvaApi().call(...)`

Important nuance:

- despite its smaller surface area, demo code uses it for both route-specific
  `page_events` and application-wide domain events from generated `AlvaEvents`.
- the cleaned-up name is now broad enough to document it as a general event
  helper rather than a page-only helper.

#### `provideAlvaPageState` and `useAlvaPageState`

Current role:

- Vue provide/inject wrapper for page-owned shared state

Important contract:

- the root LiveVue page component must call `provideAlvaPageState(...)`
- descendants may then consume `useAlvaPageState<T>()`
- calling `useAlvaPageState()` without a provider raises

Documentation consequences:

- The guide needs a dedicated Vue helper chapter. These helpers are no longer
  adequately covered by the older PRD language.
- The upload contract must be shown with a real LiveView render example, not
  only a Vue example.
- The guide should explain when to pair `useAlvaEvent` with route-specific
  generated event maps versus application-wide `AlvaEvents`.

### 6. Tooling And Code Generation Surface

There are two separate generation flows today.

#### Global domain event codegen

Entrypoint:

- `mix alva.codegen`

Generated outputs:

- `types.ts`
- `events.ts`
- `client.ts`

Observed behavior:

- `events.ts` contains globally unique domain events from host app resources
- `client.ts` generates `createAlvaApi()`
- the generated client exposes:
  - `call`
  - `on`
  - deep proxy invocation like `api.sales.fulfill(payload)`

#### Route-specific page event codegen

Entrypoint:

- compiler task `:alva_page_events`

Observed host-app wiring:

- `alva_demo/mix.exs` adds `[:phoenix_live_view] ++ Mix.compilers() ++ [:alva_page_events]`

Generated outputs:

- `<LiveViewModuleTail>.events.ts`

Observed behavior:

- route-specific page event types remain isolated per LiveView
- generated outputs model `output: AlvaResult<void>`
- `input_types` fields currently become optional TS fields in the generated file

Documentation consequences:

- The guide should document both generation flows separately.
- The guide should explain when to import `AlvaEvents` versus
  `CustomerStorefrontLiveEvents`-style page event types.
- The guide should show that `createAlvaApi()` is generated application code,
  not a package export from `alva`.

## What Should Not Be Framed As Public Surface

These modules matter for implementation and advanced debugging, but they should
not lead the guide:

- `Alva.App.Info`
- `Alva.Domain.Info`
- `Alva.Resource.Info`
- most internal helpers inside `Alva.LiveView`
- generated internal registry shapes

If mentioned, they should appear in an "internals" or "advanced debugging"
section rather than in a getting-started flow.

## Documentation Drift And Gaps

### Remediated drift

1. `docs/phase-9-realtime-model.md` now reflects the supported
   `use Alva.LiveView` activation keys and uses `api.call(...)` / `api.on(...)`
   naming consistently.
2. `docs/alva-demo-api-surface.md` now documents `support_messages` as an
   Alva Collection with `source_input:` and dynamic `route_subscriptions:`.
3. `alva/README.md` now exposes the real frontend API surface instead of the
   default package stub.
4. `docs/adr/0001-frontend-backend-contract-design.md` now uses the current
   frontend naming (`useAlvaApi`, `useAlvaForm`, and related helpers).

### Remaining guide gaps

1. Current docs still do not offer one canonical frontend helper guide that
   walks the full surface end-to-end in one place:
   - `useAlvaApi`
   - `useAlvaQuery`
   - `useAlvaEvent`
   - `useAlvaForm`
   - `useAlvaUpload`
   - `provideAlvaPageState/useAlvaPageState`
2. Active docs explain page events, page state, and route-owned collections
   across multiple files, but the guidance is still fragmented for someone
   onboarding fresh to the library.
3. If we want to fully retire older transition wording, we should add an
   explicit migration note that older helper names are obsolete in the current
   development surface.

### Coverage gaps

1. Signals are part of the public surface, but the showcase does not currently
   give a modern end-to-end example for them.
2. The distinction between domain events and page events is not yet explained in
   one place from the frontend perspective.
3. The "fail loud" authoring contract is spread across tests and implementation
   errors rather than summarized in guide form.

## Recommended Guide Structure

To cover the whole surface without mixing layers, the guide should be split
like this:

1. **Concepts And Vocabulary**
   - declaration key vs exposed name
   - command vs collection vs signal
   - source input vs route params
   - page event vs domain event

2. **Host App Setup**
   - `Alva.Resource`
   - `Alva.Domain`
   - `ash_domains`
   - `mix alva.codegen`
   - `:alva_page_events` compiler hook

3. **Resource DSL**
   - `event`
   - `collection`
   - `signal`
   - rejected legacy `stream`

4. **LiveView Activation**
   - `use Alva.LiveView`
   - `collections:`
   - `signals:`
   - `route_subscriptions:`
   - `page_events:`
   - `page_state:`
   - imperative helpers

5. **Vue Client Usage**
   - `useAlvaApi`
   - generated `createAlvaApi`
   - `useAlvaEvent`
   - `provideAlvaPageState/useAlvaPageState`
   - collection props from LiveView streams

6. **Uploads**
   - Ash file arguments
   - `allow_upload` injection
   - passing `@uploads.<name>` into LiveVue props
   - `useAlvaUpload(...).dispatch(...)`

7. **Error And Failure Contracts**
   - compile-time activation failures
   - runtime activation failures
   - dispatcher error shape
   - page event validation failure shape

8. **Migration And Legacy Notes**
   - no `domains:`
   - no `streams:`
   - no top-level `subscriptions:`
   - no declarative collection `params:`
   - manual `params:` compatibility note

## Decisions The Writing Pass Should Settle Explicitly

Before turning this into end-user docs, we should decide how strongly to bless
the following behaviors:

1. Whether `useAlvaEvent` should be the recommended default for typed event
   calls in Vue, or whether docs should prefer `createAlvaApi().call(...)` for
   some categories of usage.
2. Whether `Alva.Dispatcher.dispatch/3` is a supported advanced API or an
   internal tool that only page callbacks should call directly.
3. Whether manual `params:` compatibility on `collection/3` and
   `reload_collection/3` should appear in the public guide or stay in migration
   notes only.
4. Whether generated deep-proxy calls from `createAlvaApi()` should be promoted
   or whether docs should standardize on `api.call(...)` for clarity.

## Suggested Documentation Work Order

If the goal is guide completeness with minimal churn, the safest writing order
is:

1. replace the README stub with a surface map and quickstart
2. fix drift in `docs/phase-9-realtime-model.md`
3. update `docs/alva-demo-api-surface.md` to match current showcase behavior
4. add a dedicated guide for page activation and route lifecycle contracts
5. add a dedicated guide for Vue helpers and codegen outputs
6. add an uploads guide with one end-to-end example
