Status: ready-for-agent

# Decide And Implement Support Messages Surface

## Parent

.scratch/alva-demo-new-api-surface/PRD.md

## What to build

Make the support message list strategy explicit and implement it end to end. Because message source params depend on the selected conversation, decide whether support messages remain an ad hoc command plus pushed realtime stream, or become a manually activated route-dependent Collection owned by LiveView state.

## Acceptance criteria

- [ ] The chosen ownership model for support messages is documented in code comments, docs, or issue notes.
- [ ] Shopper and merchant chat still load historical messages for the selected conversation.
- [ ] New shopper and merchant messages appear live in the active conversation without page refresh.
- [ ] Messages for other conversations do not appear in the active chat transcript.
- [ ] Tests cover the selected support message behavior on both Storefront and Merchant Console surfaces.

## Blocked by

- .scratch/alva-demo-new-api-surface/issues/03-retire-datasync-route-collection-workarounds.md
