Status: ready-for-agent
Track: core-v2
PRD sequence: Step 2 - make the showcase consume generated subscription types

## PRD alignment

The V2 migration added typed subscription infrastructure, but the showcase still
proves most stream activation through the default `any`-friendly surface. This
slice turns the showcase into a real consumer of generated subscription
contracts so typecheck can catch drift.

## What to build

Adopt generated `AlvaSubscriptions` in the showcase Vue callsites for
stream/signal activation. Prefer small local type aliases or helper wrappers
over ad hoc casts.

Primary callsites:

- `alva_demo/assets/vue/features/storefront/CustomerStorefrontPage.vue`
- `alva_demo/assets/vue/features/merchant/MerchantConsolePage.vue`
- `alva_demo/assets/vue/features/demos/DemoNotificationsPage.vue`

If typed adoption exposes contract mismatches, resolve them through issue 01's
owning seam rather than papering over them with `as any`.

## Acceptance criteria

- [ ] Showcase `useAlvaStream` and `useAlvaSignal` callsites type against
      generated `AlvaSubscriptions`.
- [ ] `vue-tsc --noEmit` becomes a meaningful guardrail for stream/signal input
      drift in the showcase.
- [ ] No new silent widening or `as any` is introduced at subscription
      activation callsites.
- [ ] Runtime behavior for storefront, merchant console, and signal demo remains
      unchanged.

## Blocked by

- `01-subscription-input-contract-and-codegen.md`
