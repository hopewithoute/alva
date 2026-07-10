Status: ready-for-agent

## Parent

.scratch/alva-sdk-dx-overhaul/PRD.md

## What to build

Introduce a reactive query builder for one-off reads and client-side data fetching.

Build a generic `useAlvaQuery.ts` engine that accepts a reactive getter `() => input`, supports debounce, and manages `data`, `loading`, and `refetch` states. Then, update the codegen to expose `alva.domain.use_<action>_query(...)` for all `:read` actions.

End-to-end slice: Migrate a list-fetching component (e.g., `StorefrontProductCard` or similar) to use the new reactive query instead of an imperative fetch, proving auto-refresh on input change works.

## Acceptance criteria

- [ ] `useAlvaQuery.ts` engine is created and works with Vue reactivity.
- [ ] Codegen exposes `use_<action>_query` for read actions.
- [ ] A component is migrated to the new query builder and works end-to-end.

## Blocked by

- .scratch/alva-sdk-dx-overhaul/issues/02-domain-nested-sdk-core.md
