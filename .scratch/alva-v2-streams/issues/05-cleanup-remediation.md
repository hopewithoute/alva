Status: ready-for-agent

## Parent
.scratch/alva-v2-streams/PRD.md

## What to build
Perform a codebase cleanup sweep to address code review findings from the initial V2 streams implementation. Remove accidentally committed scratch files, revert stray formatting changes in untouched tests, and extract the duplicated PubSub topic string generation logic found in `Alva.LiveView` into a single, clean helper to resolve Feature Envy.

## Acceptance criteria
- [ ] `scratch.exs` and `alva_demo/test_script.exs` are deleted from the repository.
- [ ] Unrelated formatting and line-wrapping changes in `console_live_test.exs`, `synchronization_test.exs`, `storefront_live_test.exs`, and `verify_actions_test.exs` are reverted.
- [ ] Topic generation from `Ash.Notifier.PubSub.Info` in `Alva.LiveView` is centralized into a shared helper function without duplication.

## Blocked by
None - can start immediately.
