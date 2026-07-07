Status: done

## What to build
Implement Route-Specific Codegen for Page Events to ensure strict type-safety on the frontend without global naming collisions, starting with the Customer Storefront. This involves extracting the AST from the `Alva.LiveView` macro for `page_events` declarations and generating a specific `.events.ts` file (e.g. `CustomerStorefrontLive.events.ts`). Additionally, the `usePageEvent` Vue composable must be created to consume these types, followed by refactoring the `CustomerStorefrontPage.vue` to use this new composable and `ashCall`, removing the untyped `callPageEvent` wrapper and manual loading/error states.

## Acceptance criteria
- [ ] The `Alva.LiveView` macro parsing successfully outputs a route-specific TypeScript definition file for `CustomerStorefrontLive` during compilation.
- [ ] A new Vue composable `usePageEvent` is implemented in the frontend library.
- [ ] `CustomerStorefrontPage.vue` is refactored to use `usePageEvent` for its page events (`support.join_chat`, `support.reset_chat`) and no longer uses `as never`.
- [ ] The Join Chat feature works correctly end-to-end.

## Blocked by
None - can start immediately
