Status: done
Track: legacy-compatibility
PRD sequence: Outside the primary migration path; cleanup only for deprecated page-owned seams

## PRD alignment

This is cleanup for legacy compatibility surfaces. Per the PRD, we should
avoid deepening deprecated page-owned abstractions while doing this work; keep
the cleanup minimal and migration-friendly.

## What to build
Clean up the remaining codebase smells from the page-events compatibility
rollout. Simplify the overly complex validation branches around
`validate_page_event_use_declarations!/2` and any adjacent
`subscriptions:`/legacy validation logic that became duplicated during the
bridge-first pivot. Deduplicate repeated `CompileError` text in the same
module. If the duplicated support-message scope logic still needs consolidation
before subscription migration, extract only a thin helper that mirrors the
future subscription scope-resolver seam instead of deepening the deprecated
collection/route-subscription API.

## Acceptance criteria
- [x] `validate_page_event_use_declarations!/2` and adjacent legacy validation branches are simplified and readable.
- [x] Repeated `CompileError` strings in `Alva.LiveView` are consolidated.
- [x] Public JS exports remain aligned with the actual bridge-first surface (`useAlvaForm` / `useAlvaUpload`) without resurrecting removed compatibility aliases.
- [x] Any shared support-message helper stays thin and migration-oriented; no new reusable abstraction is introduced around deprecated `collections:` / `route_subscriptions:` seams.

## Blocked by
None - can start immediately
