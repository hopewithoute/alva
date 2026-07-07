Status: ready-for-agent

## What to build
Generalize the route-specific codegen mechanism to handle multiple LiveViews simultaneously without conflicts, specifically targeting the Merchant Console. Ensure that the AST extraction reliably generates `MerchantConsoleLive.events.ts`. After the codegen is proven generalized, refactor `MerchantConsolePage.vue` to adopt `usePageEvent` and `ashCall`, stripping out the manual `callPageEvent` legacy pattern completely across the demo applications.

## Acceptance criteria
- [ ] The codegen pipeline successfully emits `MerchantConsoleLive.events.ts` alongside other LiveViews.
- [ ] `MerchantConsolePage.vue` is refactored to use `usePageEvent` for `support.select_conversation`.
- [ ] All remaining `callPageEvent` references are removed from the demo applications.
- [ ] The Merchant Console conversation selection feature works correctly end-to-end.

## Blocked by
- 01-route-specific-page-events-codegen-customer-storefront.md
