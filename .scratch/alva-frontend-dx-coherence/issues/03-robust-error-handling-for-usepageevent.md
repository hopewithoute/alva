Status: ready-for-agent

## What to build
Implement proper error handling for the `usePageEvent` composable to prevent unhandled promise rejections. Currently, the composable catches and rethrows exceptions, dropping the graceful failure modes previously handled by `try/finally` blocks in the Vue components. Update `usePageEvent` to catch and expose errors safely, and ensure `CustomerStorefrontPage.vue` and `MerchantConsolePage.vue` gracefully handle these error states.

## Acceptance criteria
- [ ] `usePageEvent` catches network or API exceptions and exposes them via an `error` ref or returns a structured error payload.
- [ ] `CustomerStorefrontPage.vue` gracefully handles network errors for its page events without crashing or leaving hanging promise rejections.
- [ ] `MerchantConsolePage.vue` gracefully handles network errors.
- [ ] The loading states reset correctly even when an error occurs.

## Blocked by
None - can start immediately
