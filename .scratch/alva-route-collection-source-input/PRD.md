Status: ready-for-agent

# PRD - Alva Route Collection Source Input

## Problem Statement

Route-owned Collections need URL-driven filtering, pagination, and refresh without moving canonical list lifecycle into Vue. The current language around `params` is overloaded across Phoenix route params, Collection source input, and command/event input, which makes it hard to design a clear automation path.

## Solution

Alva will distinguish **Route Params** from **Source Input**. Route Params are URL and path params delivered by Phoenix route lifecycle callbacks. Source Input is the payload sent to a Collection source event when activating or refreshing that Collection.

Resource `live_vue` collection definitions remain reusable capability declarations. Route activation through `use Alva.LiveView` owns Source Input and route-change reload behavior. The app owns URL semantics; Alva owns Collection Refresh mechanics.

## User Stories

1. As an Ash/Phoenix developer, I want Collection source input to have a clear name, so that I do not confuse URL params with action input.
2. As a LiveView page author, I want route-owned Collections to refresh when route params change, so that filters and pagination survive refresh/back/forward without Vue owning canonical list state.
3. As a library maintainer, I want Alva to store current Source Input per active Collection, so that refresh behavior is consistent and testable.
4. As a developer building advanced routes, I want an explicit manual refresh helper, so that I can refresh a Collection without duplicating low-level activation code.
5. As a Vue developer, I want route-owned list filtering to stay on the LiveView/Collection path, so that Vue renders props instead of managing shadow query results.

## Implementation Decisions

- Use `source_input` as the preferred public name for the payload sent to a Collection source event.
- Keep existing `params` activation option as a backward-compatible alias initially.
- Use `route_params(socket)` for the URL/path params known to Alva during route lifecycle hooks.
- Use `reload_on: :route_change` as the public route lifecycle option instead of exposing Phoenix's `handle_params` name in the main API.
- Do not make Alva own URL naming conventions yet. Callback-based Source Input is the first route-change reload API.

## References

- `CONTEXT.md`
- `docs/adr/0003-collections-are-server-owned.md`
- `docs/adr/0004-route-collection-source-input.md`
- `docs/phase-9-realtime-model.md`
