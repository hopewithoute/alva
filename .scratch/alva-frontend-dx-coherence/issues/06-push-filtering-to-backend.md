Status: done
Track: legacy-compatibility
PRD sequence: Outside the primary migration path; temporary demo hardening before typed subscription migration

## PRD alignment

This issue predates the final bridge-first reset. It should be read as
temporary compatibility work to keep the demo server-driven while the showcase
still used `page_events:`, `page_state:`, and route-synced `collections:`. It
is not the target public surface for v2.

## What to build
This issue landed partially before the final v2 reset. The route-param,
`page_state`, and `page_events` plumbing now exists, but the Merchant Console
Vue tabs still keep redundant client-side filtering/computed helpers on top of
server-filtered inputs. Finish the temporary compatibility cleanup without
promoting it into the long-term v2 surface.

Refactor `MerchantConsoleLive` and the Merchant Console Vue subtree to push the
remaining filtering logic down:
1. Introduce new `page_events` (e.g. `console.filter_orders`, `console.filter_inventory`, `console.filter_conversations`) that `push_patch` to update route params.
2. Ensure the Alva collections (`sales_orders`, `products`, `conversations`) use `reload_on: :route_change`.
3. Update the `source_input` for those collections to extract the filter arguments from `route_params` and pass them to the Ash backend.
4. Update `console_page_state` to perform the global count aggregations (e.g. `new_orders_count`, `waiting_conversations_count`) using direct Ash queries, so the Vue tabs can display them even when the main lists are filtered.
5. Remove the remaining Vue-side filtering `computed` properties and helper functions, and let the Vue components directly render what the server provides.

## Acceptance criteria
- [x] Vue-side filtering `computed` properties in the Merchant Console tabs are removed.
- [x] Filtering is driven by URL params updated via `page_events`.
- [x] `page_state` provides the necessary global counts for the UI tabs.
- [x] Merchant Console renders the server-provided filtered lists directly, without double-filtering in Vue, while still treating `page_events:` / `page_state:` as temporary compatibility surfaces.
