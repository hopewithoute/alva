# Glossary

- **Alva Extension**: An Ash Extension built with Spark DSL that defines the LiveVue event contract directly within the Ash Resource. It eliminates the need for a central registry.
- **Auto-DTO**: The mechanism that gathers public fields and information during compile time (`on_compile`) from the Ash Resource to automatically generate DTOs and TypeScript definitions. It delegates conditional data redaction entirely to Ash Field Policies (like `ash_typescript` does), meaning it acts as a dumb serializer that ignores `%Ash.NotLoaded{}` or `%Ash.ForbiddenField{}`. For TypeScript Codegen, it automatically maps Ash built-in types to TypeScript types and resolves relationships recursively during compilation.
- **Projection Rule**: The shared contract used by both `event` and `subscribe` declarations to decide the client-visible payload shape. Both use **Auto-DTO** by default and may explicitly override the projection when a narrower or specialized DTO is needed.
- **Policy-Aware Optionality**: To prevent Type Mismatches when Field Policies dynamically redact required fields at runtime, the TypeScript Codegen inspects `Ash.Resource.Info.field_policies(resource)` at compile-time. Any field governed by a Field Policy is automatically generated as an optional field (`field?: type`) in TypeScript, even if `allow_nil?: false` in the database. Fields without policies remain strictly typed.
- **Auto-DTO Policy Hints**: Policy hints are injected at the global/action level by default (verifying if the actor has general permission to execute the action), rather than at the row/record level. This prevents N+1 performance bottlenecks on lists. If the user performs an action on a specific record they lack row-level access to, the system relies on the server to return a Forbidden Error. Row-level hints via Ash calculations can be an explicit opt-in for specific premium UX needs.
- **Event Result / PubSub**: Direct calls return an **Immediate Promise Reply** for instant command feedback. Meanwhile, out-of-band collection updates are projected through server-side Phoenix streams and delivered to Vue through LiveVue stream diffs, while non-collection occurrences use **Signals**.
- **Command**: A client-initiated request/reply interaction where Vue sends domain intent to the server and receives immediate success, validation, or error feedback. Commands answer what happened to this caller's request.
- **Route Subscription**: The page/socket-level choice of which concrete channel or PubSub topic a LiveView listens to for the current route, actor, tenant, or session. Route subscriptions provide realtime scope and may be declared through a thin Alva helper or raw Phoenix PubSub; they do not decide whether an incoming occurrence updates a collection or invokes a callback.
- **Stream**: A collection projection of occurrences received through a **Route Subscription**. Streams keep canonical lists current across windows or users after server state changes, and their resource-level mappings are triggered by Ash PubSub published event names.
- **Route Collection**: A stream-backed collection that belongs to the current LiveView route. Route collections are initialized and mutated server-side with Phoenix stream operations, and LiveVue applies stream diffs to Vue props.
- **Stream Query**: A page-level binding that applies a paginated or filtered command result to an active **Route Collection** using server-side Phoenix stream operations such as append, prepend, reset, and limit. Vue does not manually reconcile stream-owned collection data.
- **Signal**: A semantic callback projection of occurrences received through a **Route Subscription** for non-collection cases such as async job progress, async completion, presence, typing, or UI notifications. Signals use domain-unique names, announce that something happened, and do not own collection synchronization.
- **Resource Projection**: A reusable **Stream** or **Signal** mapping declared at the resource contract boundary. Resource projections define what occurrences may become client-visible state or callbacks, but they are inactive until a page chooses them.
- **Page Projection**: The LiveView-level activation of selected **Resource Projections** for occurrences received through a **Route Subscription**. The same occurrence may be projected differently by different pages, such as a list page updating a collection and a notification bar showing a callback notification.
- **Projection Reuse**: The same server occurrence may back both a **Stream** and a **Signal**. Duplication is resolved by page-level activation rather than being rejected at the resource boundary.
- **Projection Trigger**: The `on:` value in a **Stream** or **Signal** projection. It references an Ash PubSub published event name and is intentionally distinct from an Alva command `event`.
- **Alva Client API**: A suite of custom Vue-side wrappers and composables that provide a highly advanced, type-safe API over LiveVue. It includes:
  - `ashCall`: For executing remote events (mutations) and returning an immediate promise.
  - `ashQuery`: For ad hoc command/read fetching that is not owned by a route stream.
  - `ash.on`: For subscribing directly to PubSub events.
  - `ashUpload`: For seamlessly handling the upload mechanism (integrated with Ash).
  - `ashForm`: For handling forms with pure server-side auto-validation via debounce (including in-memory caching for validations that hit the DB). No client-side schema validation (e.g., Zod) is used.
- **Integrated File Uploads**: File upload validations (e.g., file types, limits) are defined natively within Ash actions. The Alva natively integrates with `ash_storage` during these actions, eliminating the need for manual LiveView `consume_uploaded_entries` processing.
- **Internal Dispatcher Table**: An O(1) lookup map generated automatically at compile-time by the Spark DSL. It routes frontend intent strings (e.g., `"students.create"`) directly to the correct Ash Resource/Action without requiring the developer to maintain a manual registry file. To ensure uniqueness across the entire system without a central registry, a **Cross-Resource Verifier** scans `Ash.Info.domains()` at compile-time to detect duplicate event names and halt compilation.
- **Dispatcher Actor Injection**: Unlike traditional plugs that use `Ash.set_actor/1` in the process dictionary, the Alva Alva explicitly extracts the actor (and tenant) from the LiveView `socket.assigns` and passes them directly to the action options (e.g., `actor: socket.assigns.current_user`) on every dispatch. This guarantees accurate state resolution throughout the long-lived LiveView process lifecycle without relying on process dictionary mutation.
- **Pure Server-Side Validation**: Alva does not generate or rely on Zod/Valibot schemas for client-side validation. All validations are routed to the server through `ashForm` debouncing.
- **Strict End-to-End Casing**: The system rigidly enforces `snake_case` from Elixir down to the Vue TypeScript client to preserve 1:1 mapping and avoid dynamic casing transformation chaos.
- **Static Field Selection**: The shape of the data returned to the client is dictated by the server's Auto-DTO. Dynamic GraphQL-style field selection is strictly prohibited to enforce server authority.
- **Opt-in Filter AST Codegen**: By default, clients cannot send complex filter ASTs. However, when an event explicitly sets `enable_filter: true`, Alva leverages `ash_typescript` generation logic to construct full, type-safe Filter AST types on the frontend.
- **Selective PubSub Subscription**: Rather than auto-subscribing to all topics, the developer explicitly registers PubSub subscriptions (e.g., `Phoenix.PubSub.subscribe(App.PubSub, "post_created")`) during `mount`. `Alva.LiveView`'s `handle_info` fallback then safely intercepts only `%Ash.Notifier.Notification{}` events and routes them to the Vue client.
- **Subscribe Block**: The resource-level DSL boundary that declares which **Signals** are allowed to reach Vue. A **Subscribe Block** matches Ash PubSub publication/source identity by default, not generic action names, and does not choose the concrete runtime PubSub topic for a page.
- **Semantic Subscribe Event**: A client-facing realtime event name exposed to Vue through an explicit `subscribe` boundary. It names the domain occurrence directly (e.g. `chat.message_created`) instead of leaking a generic transport envelope such as `ash_notification`.
- **Subscribe Payload**: The value delivered to a Vue `ash.on()` callback for a **Semantic Subscribe Event**. By default it is the projected DTO itself, not a generic `{ data, meta }` envelope.
- **Stream Block**: The resource-level DSL boundary that declares collection synchronization for a named LiveVue-owned list. A **Stream Block** groups explicit insert/update/delete `on:` mappings for Ash PubSub published event names, uses a domain-unique stream name, and is distinct from command orchestration and from a **Subscribe Block**, which delivers semantic callback events to Vue.
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
The term is currently overloaded between LiveView socket transport, Phoenix LiveView Streams, and Vue-owned reactive list updates. Phase 9 uses Phoenix stream operations plus LiveVue 1.x stream diff support as the primary collection/list update path, while **Subscribe Events** remain for semantic non-collection pushes.


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
