Status: done
Track: legacy-compatibility
PRD sequence: Outside the primary migration path; temporary hardening for deprecated `page_events:` support

## PRD alignment

This is compatibility work only. The PRD demotes `page_events:` from the
primary API, so this issue should not be read as precedent for extending that
surface beyond what is needed to keep the demo usable until typed
subscriptions take over.

## What to build
Implement route-specific codegen for the legacy `page_events:` surface to
ensure strict type-safety on the frontend without global naming collisions,
starting with the Customer Storefront. This involves generating a specific
`.events.ts` file (for example `CustomerStorefrontLive.events.ts`). Also create
the `usePageEvent` compatibility composable to consume these types, then
refactor `CustomerStorefrontPage.vue` to use this composable and `ashCall`,
removing the untyped `callPageEvent` wrapper and manual loading/error states.

## Acceptance criteria
- [x] The `Alva.LiveView` macro parsing successfully outputs a route-specific TypeScript definition file for `CustomerStorefrontLive` during compilation.
- [x] A new Vue composable `usePageEvent` is implemented in the frontend library.
- [x] `CustomerStorefrontPage.vue` compatibility flows use `usePageEvent` for their page events (`support.join_chat`, `support.reset_chat`) and no longer rely on `callPageEvent`/`as never`.
- [x] The Join Chat feature works correctly end-to-end on the compatibility path.

## Blocked by
None - completed compatibility slice
