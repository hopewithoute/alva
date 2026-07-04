Status: ready-for-agent

# Support Collection Params and Subscription Callbacks

## Parent

.scratch/alva-collection-liveview-streams/PRD.md

## What to build

Extend declarative LiveView activation so Collection source params and PubSub subscriptions can be static for simple pages or resolved through local callback names for advanced pages. This lets route, tenant, actor, session, or DB-backed context influence source params and subscription topics while keeping declarative activation as the default path.

Callbacks should fail loud. Declarative activation is page setup, not user-facing validation.

## Acceptance criteria

- [ ] Collection activation accepts static params, such as `collections: [sales_orders: [params: %{status: "new"}]]`.
- [ ] Collection activation accepts a local callback name for params, such as `params: :sales_order_params`.
- [ ] `subscriptions: ["order:created"]` subscribes connected LiveViews to static topics.
- [ ] `subscriptions: [:order_topics]` resolves local callback topics at activation time.
- [ ] Callback success accepts raw values and `{:ok, value}`.
- [ ] Callback failure `{:error, reason}` raises a clear activation error naming the Collection or subscription callback.
- [ ] Subscription callbacks resolve to a binary topic or list of binary topics; invalid shapes raise.
- [ ] Manual helpers remain available for graceful 404/redirect or conditional activation flows.

## Blocked by

- .scratch/alva-collection-liveview-streams/issues/02-activate-collections-declaratively-in-liveviews.md
