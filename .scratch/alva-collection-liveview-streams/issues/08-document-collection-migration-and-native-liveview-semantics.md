Status: ready-for-agent

# Document Collection Migration and Native LiveView Semantics

## Parent

.scratch/alva-collection-liveview-streams/PRD.md

## What to build

Update the project docs so future contributors understand that Alva Collections are a thin declarative layer over Phoenix LiveView streams and LiveVue stream diffs. The docs should show the final DSL, declarative LiveView activation, callback contracts, explicit render props, and the migration away from props-diff route collections.

## Acceptance criteria

- [ ] Docs show `collection`, `source event:`, `insert/update/delete on:`, and native LiveView options such as `at`, `limit`, and `update_only`.
- [ ] Docs show `collections: [...]` and `subscriptions: [...]` as declarative page options.
- [ ] Docs show local callback names for DB-backed or route-dependent params/topics.
- [ ] Docs state that render still explicitly passes `@streams.collection_name` to Vue.
- [ ] Docs state that Alva does not implement a custom list reconciliation engine.
- [ ] Migration notes explain when to remove `v-diff={false}` and plain assign route collections.
- [ ] Existing ADR and Phase 9 docs remain consistent with the implemented behavior.

## Blocked by

- .scratch/alva-collection-liveview-streams/issues/07-migrate-commerce-showcase-off-props-diff-workaround.md
