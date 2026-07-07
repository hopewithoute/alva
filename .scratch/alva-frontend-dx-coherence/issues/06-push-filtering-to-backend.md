Status: complete

## What to build
Because this is a demo to showcase the Alva bridge features, we must avoid doing heavy lifting (like filtering and aggregating) purely in Vue. Instead, we want to demonstrate how `page_state`, `page_events`, and route-synced `collections` can manage this complex state on the backend.

Refactor `MerchantConsoleLive` and `MerchantConsolePage.vue` to push the filtering and counting logic down:
1. Introduce new `page_events` (e.g. `console.filter_orders`, `console.filter_inventory`, `console.filter_conversations`) that `push_patch` to update route params.
2. Ensure the Alva collections (`sales_orders`, `products`, `conversations`) use `reload_on: :route_change`.
3. Update the `source_input` for those collections to extract the filter arguments from `route_params` and pass them to the Ash backend.
4. Update `console_page_state` to perform the global count aggregations (e.g. `new_orders_count`, `waiting_conversations_count`) using direct Ash queries, so the Vue tabs can display them even when the main lists are filtered.
5. Remove all the Vue-side filtering `computed` properties and helper functions, and let the Vue component directly render what the server provides.

## Acceptance criteria
- [x] Vue filtering `computed` properties in `MerchantConsolePage.vue` are removed.
- [x] Filtering is driven by URL params updated via `page_events`.
- [x] `page_state` provides the necessary global counts for the UI tabs.
- [x] The Alva bridge is fully utilized to manage data flow.
