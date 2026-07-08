# Review Audit 2026-07-08

Current-state `/review` and `$code-review` audit for every `done` issue under
`.scratch/alva-frontend-dx-coherence/issues/`.

## Verification commands

- `rtk test npm test -- useAlvaApi.spec.ts useAlvaForm.spec.ts useAlvaUpload.spec.ts usePageEvent.spec.ts useAlvaSignal.spec.ts useAlvaStream.spec.ts`
- `MIX_OS_CONCURRENCY_LOCK=0 rtk test mix test test/alva/live_view_activation_test.exs test/alva/live_view_test.exs test/alva/dispatcher_test.exs test/mix/tasks/alva_codegen_test.exs`
- `rtk test npm run test:unit -- DemoNotificationsPage.test.ts MerchantConsolePage.test.ts`
- `rtk npm run lint`
- `MIX_OS_CONCURRENCY_LOCK=0 rtk test mix test test/alva_demo_web/live/storefront_live_test.exs test/alva_demo_web/live/console_live_test.exs test/alva_demo_web/live/showcase_shell_test.exs test/alva_demo_web/live/demo_stream_pipeline_test.exs test/alva_demo_web/live/demo_primitives_live_test.exs`
- `MIX_OS_CONCURRENCY_LOCK=0 rtk err mix compile --warnings-as-errors` in `alva` and `alva_demo`
- `rtk rg -n "callPageEvent|useAlvaQuery|useAlvaEvent|useAlvaPageState|provideAlvaPageState" alva alva_demo -g '!**/*.md'`

## Findings

- No blocking findings were identified in the current tree.

## Issue-by-issue result

- `01-prefactor-v1-cleanup`: No blocking findings. Removed V1 helpers are absent from source, and `alva/assets/js/index.ts` now exposes only the bridge-first surface plus compatibility `usePageEvent`.
- `01-route-specific-page-events-codegen-customer-storefront`: No blocking findings. `CustomerStorefrontLive.events.ts` exists, `usePageEvent.spec.ts` passes, and `storefront_live_test.exs` keeps the storefront compatibility flow green.
- `02-global-topic-map-codegen`: No blocking findings. Core `alva` tests and `alva_codegen_test.exs` pass, and generated `subscriptions.ts` is present in the demo app.
- `02-dx-rollout-and-codegen-generalization-merchant-console`: No blocking findings. `MerchantConsoleLive.events.ts` exists, `callPageEvent` is gone from app source, and Merchant Console live/unit tests pass.
- `03-remove-optimistic-projection`: No blocking findings. `dispatcher_test.exs`, `live_view_test.exs`, and `demo_stream_pipeline_test.exs` keep the PubSub-only stream update path covered.
- `03-robust-error-handling-for-usepageevent`: No blocking findings. `usePageEvent.spec.ts` passes and the storefront plus Merchant Console compatibility paths stay green.
- `04-e2e-signal-pipeline`: No blocking findings. `useAlvaSignal.spec.ts`, core LiveView activation/runtime tests, `DemoNotificationsPage.test.ts`, and the notifications route smoke test all pass.
- `04-liveview-macro-refactoring-and-cleanup`: No blocking findings. Core `alva` tests pass, compile warnings-as-errors stays clean, and the refactor remains behavior-preserving.
- `05-e2e-stream-pipeline`: No blocking findings. `demo_stream_pipeline_test.exs` proves activation plus `loadMore(...)`, and core runtime tests stay green.
- `05-pure-ast-extraction-for-page-events-codegen`: No blocking findings in the current tree. Generation remains compile-safe and the emitted route-specific `.events.ts` files are still present after the later reflection refactor.
- `06-form-and-upload-adapters`: No blocking findings. `useAlvaForm.spec.ts`, `useAlvaUpload.spec.ts`, and Merchant Console upload tests all pass.
- `06-push-filtering-to-backend`: No blocking findings. Merchant Console unit/live tests verify server-owned filtering and route-driven compatibility events.
- `07-refactor-codegen-to-compiled-reflection`: No blocking findings. Core compile/codegen tests pass, compile warnings-as-errors stays clean, and generated route-specific event files remain available.
- `07-resubscription-robustness`: No blocking findings. `useAlvaStream.spec.ts` now covers eager activation suppression, reactive input reactivation, unmount cleanup, and `loadMore(...)`; the demo stream pipeline test covers the end-to-end path.
- `08-showcase-migration-docs`: No blocking findings. `docs/alva-demo-api-surface.md`, `CONTEXT.md`, and `docs/phase-9-realtime-model.md` consistently treat the old page-owned surfaces as compatibility or historical material, while showcase shell/live tests remain green.
