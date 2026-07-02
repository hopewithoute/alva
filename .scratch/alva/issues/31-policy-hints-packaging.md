Status: done

## Parent
`.scratch/alva/issues/29-backend-architectural-completion.md`

## Task 31: Policy Hints Packaging

**Description:** Update `Alva.Dispatcher` to inspect the results returned by Ash. Any field or calculation key that matches the regex `^can_.*` should be grouped and moved into the `meta._permissions` object in the JSON response, removing them from the main `data` object.

**Acceptance criteria:**
- [ ] Keys starting with `can_` are extracted from the record payload.
- [ ] Extracted keys are placed inside `meta: { _permissions: { ... } }`.
- [ ] The original keys are removed from the `data` payload.

**Verification:**
- [ ] ExUnit tests pass showing that an Ash calculation like `can_archive: true` is properly formatted as `meta: { _permissions: { can_archive: true } }`.

**Dependencies:** Issue 30
**Estimated scope:** Small
