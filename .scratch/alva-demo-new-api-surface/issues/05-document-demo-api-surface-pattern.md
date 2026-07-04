Status: ready-for-agent

# Document Demo API Surface Pattern

## Parent

.scratch/alva-demo-new-api-surface/PRD.md

## What to build

Document the final demo API surface pattern so future showcase changes follow the current Alva model. The note should explain which showcase lists are Collections, which data remains plain props or ad hoc commands, and why support messages are handled specially if they remain route-dependent.

## Acceptance criteria

- [ ] Documentation states that route-owned orders, products, and conversations use Alva Collections.
- [ ] Documentation shows that LiveViews pass Collection data to Vue through explicit `@streams.*` props.
- [ ] Documentation states when plain assigns are still appropriate for non-Collection props.
- [ ] Documentation captures the support message ownership decision from the implementation slice.
- [ ] Documentation warns against reintroducing plain assign plus stream-query workarounds for route-owned lists.

## Blocked by

- .scratch/alva-demo-new-api-surface/issues/01-products-collection-powers-storefront-and-console.md
- .scratch/alva-demo-new-api-surface/issues/02-conversations-collection-powers-merchant-console.md
- .scratch/alva-demo-new-api-surface/issues/03-retire-datasync-route-collection-workarounds.md
- .scratch/alva-demo-new-api-surface/issues/04-decide-and-implement-support-messages-surface.md
