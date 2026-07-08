Status: done
Track: legacy-compatibility
PRD sequence: Outside the primary migration path; compatibility safety work for deprecated `page_events:` support

## PRD alignment

This is safety work for a compatibility surface. The PRD demotes
`page_events:`, so the goal here is to harden the legacy pages without
expanding `usePageEvent` into a larger long-term API.

## What to build
Close the remaining transport/error gap in the `usePageEvent` compatibility
composable. The current composable already exposes reply-level failures through
an `error` ref, but it still assumes `pushEvent` will always yield a callback.
Harden thrown transport failures / callback absence, and ensure the storefront
and merchant compatibility flows recover without hanging `isLoading`.

## Acceptance criteria
- [x] `usePageEvent` catches network or API exceptions and exposes them via an `error` ref or returns a structured error payload.
- [x] The storefront compatibility flows gracefully handle network errors for page events without crashing or leaving hanging promise rejections.
- [x] The Merchant Console compatibility flows gracefully handle network errors.
- [x] The loading states reset correctly even when an error occurs.

## Blocked by
None - can start immediately
