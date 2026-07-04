Status: ready-for-agent

# Infer Collection Source Records from Auto-DTO Projection

## Parent

.scratch/alva-collection-liveview-streams/PRD.md

## What to build

Collection sources should not declare result shape. Alva should determine the stream records from the source event's Auto-DTO or projection contract. Standard Ash list and page-like results should work automatically. Custom DTO envelopes used as Collection sources must identify their record field in the DTO/projection layer; if Alva cannot determine the records, it should fail clearly.

## Acceptance criteria

- [ ] A source event returning a standard resource list streams the returned records.
- [ ] A source event returning a supported Ash page-like result streams the page records rather than the envelope.
- [ ] Collection DSL does not grow `shape`, `records`, or `items` options.
- [ ] If a custom DTO envelope is used as a source and records cannot be inferred, compilation or activation fails with an actionable message pointing at the source event projection.
- [ ] TypeScript/DTO codegen remains the source of truth for source result shape.
- [ ] Tests cover list, page-like, and unsupported custom envelope cases.

## Blocked by

- .scratch/alva-collection-liveview-streams/issues/02-activate-collections-declaratively-in-liveviews.md
