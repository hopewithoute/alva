Status: ready-for-agent

# PRD - Alva V2 Coherence Cleanup

## Problem Statement

The bridge-first V2 migration is mostly in place, but the codebase still has a
few coherence gaps that split the actual runtime from the intended teaching
path:

- generated subscription input types do not fully match resolver defaults,
  route-owned scope, or nullable runtime behavior
- the showcase still relies on the `any`-friendly default surface instead of
  consuming `AlvaSubscriptions` end-to-end
- generated client output still promotes older signal ergonomics alongside the
  newer `useAlvaSignal` path
- older docs and some fail-loud messages still steer readers toward pre-V2
  runtime concepts

These gaps do not currently break the demo, but they weaken the main V2 claim:
"Alva gives Ash-backed typed commands and typed subscriptions to LiveVue."

## Goals

1. Align generated subscription contracts with actual runtime input truth.
2. Make the showcase consume generated subscription types so typecheck becomes a
   real regression guardrail.
3. Narrow the generated/public signal story to one primary V2 path.
4. Quarantine legacy docs and public error copy so the supported V2 path is easy
   to follow.

## Non-Goals

- Removing compatibility runtime surfaces wholesale in this pass.
- Deleting `usePageEvent` or other migration seams that still have active
  compatibility value.
- Redesigning the subscription runtime model beyond surgical contract fixes.
- Broad unrelated refactors in `alva` or `alva_demo`.

## Success Criteria

- `subscriptions.ts` expresses required, optional, and nullable input fields in
  a way that matches actual allowed caller input.
- Showcase Vue callsites type against generated `AlvaSubscriptions` without
  relying on silent widening.
- Generated client output and docs stop presenting `api.on` / `ash.on` as the
  primary V2 signal story.
- Legacy docs and fail-loud messages are clearly historical or compatibility
  references rather than the default teaching path.

## Verification

- `MIX_OS_CONCURRENCY_LOCK=0 rtk err mix compile --warnings-as-errors` in
  `alva`
- `MIX_OS_CONCURRENCY_LOCK=0 rtk err mix compile --warnings-as-errors` in
  `alva_demo`
- `MIX_OS_CONCURRENCY_LOCK=0 rtk test mix test test/mix/tasks/alva_codegen_test.exs test/alva/live_view_activation_test.exs test/alva/live_view_test.exs`
- `rtk test npm run lint` in `alva_demo/assets`
- targeted Vue and showcase route tests around typed stream/signal activation

## Slice Order

1. `01-subscription-input-contract-and-codegen`
2. `02-showcase-typed-subscription-adoption`
3. `03-generated-client-surface-narrowing`
4. `04-docs-and-legacy-message-quarantine`

## Delivery Notes

- Keep runtime behavior stable unless a contract mismatch reveals a real bug.
- Prefer changing the narrowest ownership seam first: codegen contract, then
  showcase adoption, then generated surface/docs.
- Treat compatibility surfaces as demoted, not automatically removable.
