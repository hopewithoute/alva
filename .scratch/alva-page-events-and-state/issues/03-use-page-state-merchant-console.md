Status: ready-for-agent

## Parent

This issue was spawned from the DX architectural refactor (ADR 0008).

## What to build

Apply the new `usePageState` pattern to the Merchant Console to eliminate props drilling for shared state (e.g. `merchantId`, active tab/conversation logic).

## Acceptance criteria

- [ ] `MerchantConsolePage.vue` is refactored to provide the state and stop passing global state props to its child tabs.
- [ ] Child components (e.g., `MerchantOrdersTab.vue`, `MerchantSupportTab.vue`, `MerchantInventoryTab.vue`) inject the state via `usePageState` internally.
- [ ] Manual watcher sync logic related to those props is removed.

## Blocked by

- `.scratch/alva-page-events-and-state/issues/02-use-page-state-storefront.md`
