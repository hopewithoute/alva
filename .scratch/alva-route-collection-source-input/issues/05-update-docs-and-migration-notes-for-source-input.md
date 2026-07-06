Status: completed

# Update Docs and Migration Notes for Source Input

## Parent

.scratch/alva-route-collection-source-input/PRD.md

## What to build

Update Alva documentation and examples so developers learn the locked terminology and route Collection lifecycle. The docs should teach Route Params, Source Input, Collection Refresh, and Route Change Reload, while positioning `params` as a legacy alias if it remains supported.

## Acceptance criteria

- [ ] Phase 9 realtime docs show `source_input` and `reload_on: :route_change` examples.
- [ ] Collection ownership docs explain that Resource definitions declare capability while route activation owns Source Input.
- [ ] Migration notes explain how URL-driven filters should avoid Vue-owned shadow query results.
- [ ] Docs mention `params` only as a backward-compatible alias or legacy term, not as the preferred API.
- [ ] Examples use `route_params(socket)` when deriving Source Input from the URL.

## Blocked by

- .scratch/alva-route-collection-source-input/issues/01-accept-source-input-as-collection-activation-input.md
- .scratch/alva-route-collection-source-input/issues/03-auto-refresh-collections-on-route-change.md
- .scratch/alva-route-collection-source-input/issues/04-add-explicit-collection-refresh-helpers.md
