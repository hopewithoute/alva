Status: ready-for-agent

# Synchronize Orders Across Surfaces

## What to build

Wire Order changes through Alva realtime primitives so Customer Storefront and Merchant Console pages stay in sync through Route Subscriptions, Streams, and Page Projections. This slice should prove that order collection state flows through the LiveView/LiveVue stream path rather than Vue-side list reconciliation.

## Acceptance criteria

- [ ] Order actions publish the occurrences needed for realtime synchronization.
- [ ] Order resource projections declare the Stream mappings for relevant Order changes.
- [ ] Customer Storefront and Merchant Console pages subscribe to the appropriate route topics and activate the needed Page Projections.
- [ ] A change made from one surface becomes visible on the other surface through the server stream path.
- [ ] Vue code does not manually append, dedupe, replace, or delete stream-owned Order collection data.
- [ ] Tests prove a practical cross-surface realtime behavior without testing PubSub internals directly.

## Blocked by

- 04-operate-order-lifecycle-in-merchant-console
