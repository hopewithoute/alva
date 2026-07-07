#!/usr/bin/env bash
set -euo pipefail

cd /var/www/ash_vue

rtk git add -- \
  alva/lib/alva/app/info.ex \
  alva/lib/alva/dispatcher.ex \
  alva/lib/mix/tasks/alva.codegen.ex \
  alva/test/alva/dispatcher_test.exs \
  alva/test/mix/tasks/alva_codegen_test.exs
rtk git commit -m "feat(alva): add host app registry boundary for dispatch and codegen"

rtk git add -- \
  alva/lib/alva/live_view.ex \
  alva/lib/alva/resource.ex \
  alva/lib/alva/resource/info.ex \
  alva/lib/alva/resource/verifiers/verify_actions.ex \
  alva/lib/alva/domain/info.ex \
  alva/lib/alva/domain/transformers/verify_and_persist_events.ex \
  alva/test/alva/live_view_activation_test.exs \
  alva/test/alva/live_view_test.exs \
  alva/test/alva/resource/verifiers/verify_actions_test.exs \
  alva/test/alva/domain/transformers/verify_and_persist_events_test.exs
rtk git commit -m "refactor(alva): make activation app-wide and remove stream runtime surface"

rtk git add -- \
  alva_demo/assets/vue/MerchantConsolePage.test.ts \
  alva_demo/lib/alva_demo/support/support_message.ex \
  alva_demo/lib/alva_demo_web/endpoint.ex \
  alva_demo/lib/alva_demo_web/live/customer_storefront_live.ex \
  alva_demo/lib/alva_demo_web/live/demo_chat_live.ex \
  alva_demo/lib/alva_demo_web/live/demo_load_more_live.ex \
  alva_demo/lib/alva_demo_web/live/demo_notifications_live.ex \
  alva_demo/lib/alva_demo_web/live/merchant_console_live.ex \
  alva_demo/test/alva_demo_web/live/catalog_product_dispatcher_test.exs \
  alva_demo/test/alva_demo_web/live/console_live_test.exs \
  alva_demo/test/alva_demo_web/live/sales_order_dispatcher_test.exs \
  alva_demo/test/alva_demo_web/live/support_dispatcher_test.exs \
  alva_demo/test/alva_demo_web/live/synchronization_test.exs
rtk git commit -m "refactor(alva_demo): migrate demo app to host-app registry and non-stream subscriptions"

rtk git add -- \
  CONTEXT.md \
  docs/adr/0006-host-app-registry-boundary-and-collection-signal-surface.md \
  .scratch/alva-host-app-registry-migration/issues/01-route-commands-through-host-app-registry-boundary.md \
  .scratch/alva-host-app-registry-migration/issues/02-activate-collections-and-signals-without-page-domains.md \
  .scratch/alva-host-app-registry-migration/issues/03-remove-stream-surface-and-migrate-route-owned-lists-to-collections.md
rtk git commit -m "docs(architecture): record host app registry migration and close tracker slices"

rtk git add -- \
  alva/assets/js/ashUpload.ts \
  alva/assets/js/ashUpload.spec.ts \
  alva/lib/alva/error.ex
rtk git commit -m "refactor(alva): tighten ashUpload config lookup and simplify error helpers"

echo
echo "Remaining worktree state:"
rtk git status --short
echo
echo "Image artifacts under alva_demo/priv/static/images remain intentionally uncommitted."
