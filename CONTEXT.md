# Glossary

- **Alva Extension**: An Ash Extension built with Spark DSL that defines the LiveVue event contract directly within the Ash Resource. It eliminates the need for a central registry.
- **Auto-DTO**: The mechanism that gathers public fields and information during compile time (`on_compile`) from the Ash Resource to automatically generate DTOs and TypeScript definitions. It delegates conditional data redaction entirely to Ash Field Policies (like `ash_typescript` does), meaning it acts as a dumb serializer that ignores `%Ash.NotLoaded{}` or `%Ash.ForbiddenField{}`. For TypeScript Codegen, it automatically maps Ash built-in types to TypeScript types and resolves relationships recursively during compilation.
- **Projection Rule**: The shared contract used by both `event` and `signal` declarations to decide the client-visible payload shape. Both use **Auto-DTO** by default and may explicitly override the projection when a narrower or specialized DTO is needed.
- **Policy-Aware Optionality**: To prevent Type Mismatches when Field Policies dynamically redact required fields at runtime, the TypeScript Codegen inspects `Ash.Resource.Info.field_policies(resource)` at compile-time. Any field governed by a Field Policy is automatically generated as an optional field (`field?: type`) in TypeScript, even if `allow_nil?: false` in the database. Fields without policies remain strictly typed.
- **Auto-DTO Policy Hints**: Policy hints are injected at the global/action level by default (verifying if the actor has general permission to execute the action), rather than at the row/record level. This prevents N+1 performance bottlenecks on lists. If the user performs an action on a specific record they lack row-level access to, the system relies on the server to return a Forbidden Error. Row-level hints via Ash calculations can be an explicit opt-in for specific premium UX needs.
- **Event Result / PubSub**: Direct calls return an **Immediate Promise Reply** for instant command feedback. Meanwhile, out-of-band stream updates are projected through server-side Phoenix streams and delivered to Vue through LiveVue stream diffs, while non-stream occurrences use **Signals**.
- **Action**: The Ash operation that executes domain behavior, usually named as an imperative atom like `:create`, `:begin_processing`, or `:fulfill`. Actions answer what the server is asked to do, not what happened afterward.
- **Declaration Key**: The internal atom identifier for an Alva declaration. Page-facing projection keys such as Streams and Signals are application-wide unique within a host app so compile-time registries can resolve them without page-scoped Domain filtering. Resource-local references such as a Stream source event key still use declaration keys rather than client-facing names.
- **Exposed Name**: The client-facing string name that crosses the Vue boundary. Exposed event names and exposed signal names are application-wide unique within a host app so generated SDK calls and typed Signal listeners do not depend on page-scoped Domain lookup.
- **Command**: A client-initiated request/reply interaction where Vue sends domain intent to the server and receives immediate success, validation, or error feedback. Commands answer what happened to this caller's request.
- **Publication**: An Ash PubSub declaration that says when a notification should be broadcast and how its Event and Topic are formed.
- **Event**: The published event name carried by an Ash PubSub broadcast, coming from `event:` when provided or otherwise from the publication identity such as an action name. It is transport occurrence metadata, not a client command declaration.
- **PubSub Occurrence Key**: The atom identity a resource projection listens for in `on:`, normally the Ash action atom passed to `publish`, such as `:fulfill`. It answers which publication occurrence should drive a Stream delta or Signal callback. It is distinct from a command Event Declaration Key, a concrete Topic, an exposed client name, and a raw PubSub event string.
- **Topic**: The concrete PubSub routing scope that carries an Event to interested pages, such as `"orders:all"` or `"orders:tenant:123"`. Topics answer who should receive a publication, not what happened semantically.

- **Subscription Block**: The resource-level DSL boundary that declares what server-owned reactive streams or callbacks are allowed to reach Vue.
- **Stream**: A unified data delivery capability formally adopted in ADR 0009. Data delivery is strictly separated from lifecycle intent: Server projects occurrences into native LiveView streams, which LiveVue syncs to Vue props. Vue uses `useAlvaStream` solely to declare lifecycle intent, never to receive raw data payloads.
- **Page Scope**: The page-owned context that determines which route state and realtime scope are active for the current LiveView, such as route params, tenant, actor, or session. Page Scope may feed Stream Input, but it is not itself a projection.
- **Route Params**: URL and path params delivered by Phoenix route lifecycle callbacks such as `handle_params/3`. Route Params describe page state, not Ash action input.
- **Signal**: A semantic callback projection of occurrences for non-stream cases such as async job progress, async completion, presence, typing, or UI notifications. Signals use application-wide unique client names, announce that something happened, do not own stream synchronization, and follow the same page activation shape as Streams.
- **Event Declaration**: A resource-level command/read exposure whose internal identity is an atom **Declaration Key** while its client-facing command name is carried by `name: "..."`. Event Declarations are for Vue-to-server calls and Stream sources, not for PubSub occurrence matching.
- **Projection Trigger**: The `on:` value in a **Stream** operation or **Signal** projection. It references a **PubSub Occurrence Key**, not a command Event Declaration Key, a concrete Topic, an exposed client name, or a raw PubSub event string.
- **Signal Declaration**: A resource-level semantic callback exposure whose internal identity is an atom **Declaration Key** while its client-facing callback name is carried by `name: "..."`.
- **Resource Projection**: A reusable **Stream** or **Signal** mapping declared at the resource contract boundary. Resource projections define what occurrences may become client-visible state or callbacks, but they are inactive until a page chooses them. Public route-owned list state should be described as Streams, not Stream-based page activation.
- **Page Projection**: The LiveView-level activation of selected **Resource Projections**. The same occurrence may be projected differently by different pages, such as a list page updating a stream and a notification bar showing a callback notification.
- **Activation Surface**: The page-facing layer used to wire realtime behavior. Alva exposes declarative activation with `subscriptions:`. Legacy definitions and imperative Stream helpers outside the Alva projection contract are invalid and should fail loudly.
- **Domain SDK Surface**: The generated client-callable Alva SDK surface is not page-scoped. Client Event Declarations are callable through a compile-time registry assembled from the host app's configured `ash_domains`, while authorization remains the responsibility of Ash policies and auth context rather than page-level allowlists.
- **Global Command Registry**: The application-wide registry assembled from compile-time metadata in the host app's configured `ash_domains`. It maps exposed client Event names to their Resource and Action metadata for SDK dispatch. Runtime should resolve it by host app context such as `otp_app`, may cache the assembled table in stable environments, should prefer uncached assembly in iterative environments like dev/test, and must never narrow command lookup through page-scoped Domains.
- **Global Projection Registry**: The application-wide registry assembled from compile-time metadata in the host app's configured `ash_domains` for page-facing Streams, Signals, and upload metadata. `use Alva.LiveView` activates projections by declaration key from this host app registry and should not require page-scoped `domains:` input. Runtime may cache the assembled registry per host app in stable environments, should prefer uncached assembly in iterative environments like dev/test, and projection identity remains compile-time-authored.
- **Host App Registry Boundary**: The library-level seam where Alva resolves a host app's configured `ash_domains` and assembles application-wide command and projection registries. Page activation, SDK dispatch, and code generation depend on this host app boundary rather than on page-scoped Domain selection or duplicated aggregation logic.
- **Registry Module**: A unified deep module (`Alva.Registry`) that consolidates DSL extraction across Spark boundaries, traversing all domains internally, and exposing a single API for fetching aggregated registry maps.
- **Serializer Module**: A unified deep module (`Alva.Serializer`) that acts as an adapter for turning Ash records into JSON-friendly payloads, relying on primitive options like `expose_metadata: [...]` rather than overloaded UI concepts like Signals or Events.
- **Host App Compile-Time Verification**: Application-wide uniqueness and activation-surface validation should fail while compiling the consumer host app, where `ash_domains` are known. These checks should piggyback on the existing domain compile path without extra setup, custom compilers, or explicit verification tasks, while remaining tolerant of normal host-app compile order instead of forcing new sibling-domain compilation dependencies. Compiling the Alva library in isolation without a host app registry context should remain a safe no-op for those host-app-level checks.
- **Activation Declaration Form**: Public declarative page activation uses only the keyword form of `use Alva.LiveView` and should expose only page-owned concerns such as `subscriptions:`. Legacy tuple forms and page-scoped `domains:` are not part of the supported surface because they bypass or duplicate host app registry resolution and should fail at compile-time without a deprecation shim.
- **Activation Validation**: Alva validates page activation strict layers. First, declarative page activation must match the allowlisted public surface and allowed nested option shapes. Both layers fail loudly rather than silently widening behavior or falling back to legacy paths.
- **Activation Failure Timing**: Invalid declarative activation shape fails at compile-time because it is knowable from the `use Alva.LiveView` declaration itself.
- **Projection Activation Uniqueness**: A page may activate a given Stream or Signal at most once in declarative page activation. Duplicate entries in `subscriptions:` are declaration conflicts and should fail at compile-time.
- **Page Projection Namespace**: Declarative page activation uses one shared projection-key namespace across `subscriptions:`. A page may not activate the same Declaration Key as both a Stream and a Signal.
- **Projection Reuse**: The same server occurrence may back both a **Stream** and a **Signal**. Duplication is resolved by page-level activation rather than being rejected at the resource boundary.
- **Alva Client API**: The primary v2 Vue-side surface is a thin Ash-aware layer over LiveVue. It includes:
  - `useAlvaApi` and generated helpers such as `ashCall`: For executing remote commands or ad hoc request/reply reads and returning an immediate promise.
  - `useAlvaStream`: For declaring Stream lifecycle intent only. Canonical route-owned list data still arrives from LiveView props / `@streams.*`, not from the composable return value.
  - `useAlvaSignal`: For typed Signal lifecycle management and callback registration.
  - `useAlvaUpload`: For seamlessly handling upload flows integrated with Ash.
  - `useAlvaForm`: For pure server-side auto-validation via debounce (including in-memory caching for validations that hit the DB). No client-side schema validation (for example Zod) is used.
  - `usePageEvent`: A compatibility surface for page-local UI orchestration during migration. It relies on route-specific codegen rather than the global registry and is not the primary v2 teaching path.
  - `ashQuery`, `providePageState`, and `usePageState`: Demoted or removed compatibility surfaces that should not be treated as the default bridge-first API.
- **Integrated File Uploads**: File upload validations (e.g., file types, limits) are defined natively within Ash actions. The Alva natively integrates with `ash_storage` during these actions, eliminating the need for manual LiveView `consume_uploaded_entries` processing.
- **Internal Dispatcher Table**: An O(1) lookup map assembled from compile-time metadata in the host app's configured `ash_domains`. It routes frontend intent strings (e.g., `"students.create"`) directly to the correct Ash Resource/Action without requiring the developer to maintain a manual registry file. Cross-resource verification should halt compilation when exposed names collide inside the same host app registry.
- **Dispatcher Actor Injection**: Unlike traditional plugs that use `Ash.set_actor/1` in the process dictionary, the Alva Alva explicitly extracts the actor (and tenant) from the LiveView `socket.assigns` and passes them directly to the action options (e.g., `actor: socket.assigns.current_user`) on every dispatch. This guarantees accurate state resolution throughout the long-lived LiveView process lifecycle without relying on process dictionary mutation.
- **Pure Server-Side Validation**: Alva does not generate or rely on Zod/Valibot schemas for client-side validation. All validations are routed to the server through `useAlvaForm` debouncing.
- **Strict End-to-End Casing**: The system rigidly enforces `snake_case` from Elixir down to the Vue TypeScript client to preserve 1:1 mapping and avoid dynamic casing transformation chaos.
- **Static Field Selection**: The shape of the data returned to the client is dictated by the server's Auto-DTO. Dynamic GraphQL-style field selection is strictly prohibited to enforce server authority.
- **Opt-in Filter AST Codegen**: By default, clients cannot send complex filter ASTs. However, when an event explicitly sets `enable_filter: true`, Alva leverages `ash_typescript` generation logic to construct full, type-safe Filter AST types on the frontend.
- **Selective PubSub Subscription**: Alva only listens to Topics a page explicitly activates. `Alva.LiveView`'s `handle_info` fallback then safely intercepts `%Ash.Notifier.Notification{}` events and routes them into active projections.
- **Signal Event Name**: The application-wide client-facing realtime `name: "..."` exposed to Vue through a Signal declaration. It names the domain occurrence directly (e.g. `chat.message_created`) instead of leaking a generic transport envelope such as `ash_notification`.
- **Signal Payload**: The normalized map payload delivered to a Vue `useAlvaSignal()` callback or equivalent typed Signal listener. DTO-shaped payloads are passed through as maps, scalar or list payloads are wrapped under `data`, and optional metadata lives under `meta`.
- **Alva.LiveView Hijack**: A required macro (`use Alva.LiveView`) that hooks into LiveView's lifecycle. Crucially, it hijacks `mount` to dynamically inject `allow_upload` for any exposed events requiring `ash_storage`, providing true zero-boilerplate file uploads. It also provides automatic fallbacks for `handle_event` (to route to the Dispatcher) and `handle_info` (for PubSub bridging).
- **Custom Metadata Opt-in**: Execution metadata (`record.__metadata__`) is stripped by default to prevent internal leaks. It is only included if explicitly registered via `expose_metadata: [...]` in the DSL, and is cleanly isolated under the `meta` key in the JSON response to separate it from core domain data.
- **Action Exposure Verifier**: A compile-time check in the Alva extension that halts compilation if an `event` in the `live_vue` block maps to an Ash action that is not marked `public?: true`. It acts as a hard boundary to ensure internal actions are never accidentally exposed to the Vue client.
- **Empty DTO Warning**: A compile-time warning emitted by the Alva extension if an exposed event maps to an action that produces no client-visible fields (e.g., a generic action with no `returns` type or a resource with all private fields), alerting developers that Vue will receive an empty payload.
- **Actor/Tenant Omission Warning**: A runtime warning logged by `Alva.Dispatcher.dispatch` when it processes a command but cannot find a configured actor or tenant in the `socket.assigns`, ensuring developers don't accidentally execute actions unauthenticated in a multi-tenant environment.
- **Explicit Exposure Principle**: The foundational security boundary in Alva that requires all client-callable actions to be explicitly declared in the `live_vue` block. Auto-exposure modes are fundamentally unsupported to prevent accidental leaking of domain operations.
- **Alva Test Helpers**: Utilities (e.g., `assert_dispatch_ok`, `assert_dispatch_forbidden`) that allow developers to test the exact authorization boundary Vue interacts with, without writing raw boilerplate dispatcher code in ExUnit tests.
- **Error Redaction Rule**: Alva's environment-aware error masking. In production, unhandled or internal errors are redacted into a generic `unknown` payload to prevent detail leakage. In development, the full error details are sent to the Vue client for debugging. In both cases, the complete error is logged to the server console.
- **Alva Telemetry Events**: Standard Erlang `:telemetry` events emitted by `Alva.Dispatcher` containing the actor, event name, parameters, and result/duration. This is the idiomatic way host applications hook into Alva for audit logging or metrics without tightly coupling to specific callbacks.

## Flagged ambiguities

**Stream API**:
The term is currently overloaded between LiveView socket transport, Phoenix LiveView Streams, and Vue-owned reactive list updates. Phase 9 uses Phoenix stream operations plus LiveVue 1.x stream diff support as the primary stream/list update path, while **Signals** remain the semantic non-stream push path.


# Alva Commerce Showcase

This context describes a sample commerce application for demonstrating Alva in realistic customer-facing and admin operations workflows.

## Language

**Customer Storefront**:
The customer-facing surface where shoppers browse products and place orders.
_Avoid_: Shop page, public demo

**Merchant Console**:
The admin-facing surface where merchant staff monitor orders, update fulfillment status, and respond to operational events.
_Avoid_: Admin panel, dashboard

**Order Lifecycle**:
The intentionally small, linear sequence of order states used to exercise the Alva library surface.
_Avoid_: Order workflow, status flow

**Inventory Snapshot**:
A lightweight view of current product stock used to support order operations without modeling full warehouse management.
_Avoid_: Warehouse system, stock module

**Product Media**:
Uploaded product imagery owned directly by a Product and used to demonstrate file upload behavior in the showcase catalog.
_Avoid_: Asset manager, media library

**Support Chat**:
A lightweight conversation surface between shoppers and merchant staff, organized as one conversation per customer without modeling a full helpdesk.
_Avoid_: Helpdesk, ticketing system

**Conversation**:
A single support thread for one customer in the showcase.
_Avoid_: Ticket, room

**Customer Name**:
A shopper-provided label used to distinguish orders and conversations in the showcase without modeling accounts or authentication.
_Avoid_: User account, profile
