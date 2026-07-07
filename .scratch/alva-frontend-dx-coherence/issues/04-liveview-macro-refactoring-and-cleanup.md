Status: ready-for-agent

## What to build
Clean up the remaining codebase smells from the page events DX rollout. Simplify the overly complex `shape when` guard clause in `Alva.LiveView.validate_page_event_use_declarations!/2`. Deduplicate the three identical `CompileError` string definitions in the same module. Revert the unrelated `export * from "./ashForm"` change back to `export { ashForm }` in `alva/assets/js/index.ts`. Finally, extract the duplicated `support_message` collection logic (`support_message_collection_source_input` and `support_message_route_topics`) from both `CustomerStorefrontLive` and `MerchantConsoleLive` into a shared helper module.

## Acceptance criteria
- [ ] `validate_page_event_use_declarations!/2` guard clauses are simplified and readable.
- [ ] `CompileError` strings in `Alva.LiveView` are consolidated.
- [ ] `alva/assets/js/index.ts` export is reverted to `export { ashForm }`.
- [ ] `support_message` mapping logic is deduplicated across the demo LiveViews.

## Blocked by
None - can start immediately
