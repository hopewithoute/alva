Status: ready-for-agent

## Parent

This issue was spawned from the DX architectural refactor (ADR 0008).

## What to build

Implement the `usePageState` composable in the Alva Vue package to automatically inject LiveView state (like `customerName` and `activeConversationId`), completely eliminating props drilling and brittle manual `watch` initializations in the Customer Storefront.

## Acceptance criteria

- [ ] `usePageState` composable is implemented and exported from the `alva` Vue package, utilizing Vue's `provide/inject`.
- [ ] The top-level component provides the state from the `live_vue` properties.
- [ ] `CustomerStorefrontPage.vue` is refactored to use `usePageState` and no longer passes `customerName` and `active_conversation_id` as props to its children.
- [ ] `StorefrontHeader.vue` and `SupportChatWidget.vue` are refactored to inject `usePageState` internally.
- [ ] All manual `watch` blocks syncing props to local refs in the storefront are removed.

## Blocked by

None - can start immediately (can run in parallel with Issue 01)
