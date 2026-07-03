Status: done

## Parent
`.scratch/alva/issues/29-backend-architectural-completion.md`

## Task 32: Custom Metadata Opt-in

**Description:** Add DSL support for `expose_metadata: [...]` inside the `live_vue` event entity. Update `Alva.Dispatcher` to read this configuration and extract the permitted keys from `record.__metadata__` (or the action result metadata), injecting them into the `meta` object of the JSON response.

**Acceptance criteria:**
- [x] Developer can configure `expose_metadata: [:sync_token]` in the event DSL.
- [x] Dispatcher correctly transfers `sync_token` from `__metadata__` to the JSON `meta` object.
- [x] Unexposed metadata remains fully stripped.

**Verification:**
- [x] ExUnit tests show that exposed metadata is retained in `meta` and unexposed metadata is discarded.

**Dependencies:** Issue 30
**Estimated scope:** Small
