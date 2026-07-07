Status: done

## What to build

Enhance `Alva.Dispatcher` to respect the `get?: true` flag on Ash actions. When processing an event mapped to a `:read` action that has `get?: true`, the dispatcher should automatically unwrap the resulting list and return the single record (or return a Not Found error if the list is empty), rather than returning the raw list. This ensures that the frontend and backend consumers of `Alva.Dispatcher.dispatch` receive a single object, matching the semantics of a `get` action.

The TypeScript code generator (`alva.build`) may also need a minor adjustment if it currently emits an array type for these actions.

## Acceptance criteria

- [ ] `Alva.Dispatcher` checks `action.get?` on the Ash action metadata during a `:read` dispatch.
- [ ] If `get?: true` is present, the dispatcher returns a single struct/map on success (e.g., `%{ok: true, data: %Resource{}}`), rather than a list.
- [ ] If `get?: true` is present and no record is found, the dispatcher returns a Not Found error.
- [ ] (Optional but recommended) The TypeScript codegen outputs a single object type instead of an array type for events mapped to `get?: true` actions.
- [ ] The `set_identity_page_event` workaround in `customer_storefront_live.ex` can safely be reverted to expect a single map/struct instead of a list.

## Blocked by

None - can start immediately
