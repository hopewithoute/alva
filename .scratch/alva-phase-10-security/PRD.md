Status: ready-for-agent

## Problem Statement

Alva integrates Vue with Ash and LiveView, exposing domain actions directly to the frontend. Without strict boundaries, there is a risk of accidentally leaking internal actions, exposing full stack traces or sensitive internal error details to the client, or executing multi-tenant actions without the correct authentication context. The framework must protect developers from these unsafe usage patterns by default.

## Solution

Phase 10 introduces a comprehensive security hardening layer. It enforces explicit boundaries at compile-time (preventing non-public actions or empty payloads from being exposed), protects runtime execution (warning on missing authentication context), standardizes error redaction (hiding internal details in production), and emits standard telemetry events for robust audit trailing.

## User Stories

1. As a developer, I want compilation to fail if I expose an action that is not `public?: true`, so that I don't accidentally leak internal domain operations.
2. As a developer, I want a compile-time warning if I expose an action that returns no public fields, so that I don't deploy an endpoint that sends useless empty payloads to the client.
3. As a developer, I want a runtime warning logged if the dispatcher executes an action but my LiveView forgot to set an actor/tenant in the socket, so that I catch unauthenticated multi-tenant executions early.
4. As a security reviewer, I want to rely on the Explicit Exposure Principle, so that I know no auto-expose modes exist and every exposed endpoint is visible in the resource DSL.
5. As a developer, I want `Alva.Test` helpers like `assert_dispatch_ok` and `assert_dispatch_forbidden`, so that I can easily write tests that mimic the exact authorization boundary Vue interacts with.
6. As a user on a production system, I want internal server errors to be redacted into a generic `unknown` message, so that sensitive internal stack traces or database schema details are not leaked.
7. As a developer in a local environment, I want to receive full internal error details in the Vue payload, so that I can easily debug failing actions during development.
8. As a system administrator, I want Alva to emit standard `:telemetry` events on every dispatch, so that I can attach audit logs and metrics without tightly coupling to specific callbacks.

## Implementation Decisions

- **Action Exposure Verifier:** Implement a check in the Alva extension's `on_compile` or transformer phase. If an event maps to an action without `public?: true`, raise a `Spark.Error.DslError`.
- **Empty DTO Warning:** Implement a check in the Alva extension's `on_compile` or transformer phase. If an action's returned DTO has 0 fields, use `Logger.warning` to alert the developer.
- **Actor/Tenant Omission Warning:** Modify `Alva.Dispatcher.dispatch` to check `socket.assigns.current_user` and `current_tenant` (or the equivalent keys). If missing, emit a `Logger.warning`.
- **Explicit Exposure Principle:** Enforce the lack of auto-expose modes natively (no new configuration options for exposing all will be built).
- **Alva Test Helpers:** Create a new module `Alva.Test` providing ExUnit assertions (`assert_dispatch_ok`, `assert_dispatch_forbidden`) that wrap `Alva.Dispatcher`.
- **Error Redaction Rule:** Update `Alva.Error` to check the environment (e.g. `Application.get_env(:alva, :env)` or `Mix.env()`). If in prod, convert all unknown/internal errors to a generic payload. Log the full error to the server console regardless of the environment.
- **Alva Telemetry Events:** Modify `Alva.Dispatcher.dispatch` to call `:telemetry.execute([:alva, :dispatch, :stop], %{duration: ...}, %{event: event, actor: actor, params: params, result: result})`.

## Testing Decisions

Tests will be written against the following seams, aiming for the highest possible integration points:
1. **Compilation Seam:** Using dynamically generated modules in ExUnit (or checking `Spark.Dsl` compiler callbacks) to assert that invalid DSLs (non-public actions, empty fields) raise errors or emit warnings. Prior art: Standard Ash framework DSL tests.
2. **Runtime Dispatcher Seam:** Testing `Alva.Dispatcher.dispatch/3` directly in ExUnit to assert that omitted actors log warnings, and that internal errors are redacted based on the application environment. Prior art: Controller or LiveView event tests.
3. **Telemetry Seam:** Attaching a temporary `:telemetry` handler in a test to assert that `[:alva, :dispatch]` events are emitted with the correct metadata. Prior art: Phoenix or Ecto telemetry tests.

## Out of Scope

- Adding client-side Zod or Valibot schema validation.
- Automatically protecting actions based on external permission registries (all authorization relies strictly on Ash Policies).
- Creating a graphical dashboard for telemetry metrics.

## Further Notes

None.
