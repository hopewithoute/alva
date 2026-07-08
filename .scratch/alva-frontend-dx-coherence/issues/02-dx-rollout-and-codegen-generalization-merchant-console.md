Status: done
Track: legacy-compatibility
PRD sequence: Outside the primary migration path; finish compatibility rollout after the page-event codegen hardening

## PRD alignment

The PRD demotes `page_events:` from the primary API. This issue should only
finish demo adoption of the already-built compatibility tooling; it should not
expand `page_events:` as a strategic surface.

## What to build
Finish Merchant Console adoption of the already-generalized route-specific page
event codegen. The infrastructure for emitting multiple LiveView `.events.ts`
files is now treated as complete; the remaining work is rollout and legacy
cleanup in the demo applications. In the current component split, the event
adoption lives across the Merchant Console Vue subtree rather than only in
`MerchantConsolePage.vue`. Strip out the manual `callPageEvent` pattern
completely across the demo applications.

## Acceptance criteria
- [x] The existing codegen pipeline emits `MerchantConsoleLive.events.ts` without manual intervention.
- [x] The Merchant Console Vue subtree adopts `usePageEvent` for `support.select_conversation` and filter events.
- [x] All remaining `callPageEvent` references are removed from the demo applications.
- [x] The Merchant Console conversation selection feature works correctly end-to-end on the compatibility path.

## Blocked by
- None - completed compatibility rollout
