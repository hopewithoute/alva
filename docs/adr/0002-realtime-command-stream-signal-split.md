# Realtime Command, Collection, Signal, and Route Subscription Split (Historical)

> Historical ADR kept for legacy Phase 9 context.
> For the supported V2 path, start with [ADR 0009](./0009-alva-v2-stream-boundary-and-api.md)
> and [docs/alva-demo-api-surface.md](../alva-demo-api-surface.md).

Phase 9 separates realtime communication into Commands, Collections, Signals, Route Subscriptions, and Page Projections. Commands remain Vue-to-server request/reply interactions. Collections are server-owned route state made from a required Collection Source plus optional Event-triggered delta mappings, applied internally with Phoenix stream operations that LiveVue delivers to Vue as stream diffs. Signals are semantic non-collection callbacks. Route Subscriptions decide which concrete Topics reach the page, while Page Projections decide how a matching Event is projected once it arrives. Collection refresh and parameter changes stay on the LiveView/Collection path instead of binding command read replies directly into route lists. This keeps collection synchronization on the LiveView/LiveVue stream path while avoiding a second client-side list reconciliation path through `ash.on()`.
