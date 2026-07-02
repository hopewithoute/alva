Status: done

## Parent
`.scratch/alva/issues/29-backend-architectural-completion.md`

## Task 30: Compile-Time Auto-DTO Extraction & Strict Payload Stripping

**Description:** Implement an `on_compile` hook in `Alva.Resource` to gather all `public?: true` attributes, calculations, and relationships. Update `Alva.Dispatcher.strip_metadata/1` to strictly filter returned records based on this public list, natively dropping `%Ash.NotLoaded{}` and `%Ash.ForbiddenField{}`.

**Acceptance criteria:**
- [ ] `Alva.Resource` exposes a function (e.g., `Alva.Domain.Info.public_fields(resource)`) that returns a list of public fields.
- [ ] `Alva.Dispatcher` filters out any field not present in the public list before returning data to the client.
- [ ] Internal fields (like `password_hash` or `__meta__`) are automatically dropped.

**Verification:**
- [ ] ExUnit tests for `Alva.Dispatcher` assert that private fields are not present in the `data` payload.

**Dependencies:** None
**Estimated scope:** Small
