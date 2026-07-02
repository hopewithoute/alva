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

## Comments

**Deviation Record (2026-07-03):**
The original PRD specification required building a custom `on_compile` hook within `Alva.Resource` to extract the `public?: true` list of fields. However, during implementation, it was decided to omit this custom hook. 

*Rationale*: Ash Framework's internal compiler already performs this exact extraction at compile-time and natively exposes it via `Ash.Resource.Info` (e.g., `public_attributes/1`, `public_relationships/1`). Therefore, creating an identical `on_compile` macro in `Alva` would violate the DRY principle (Speculative Generality). By querying `Ash.Resource.Info` directly inside `Alva.Dispatcher.strip_metadata/1`, we still achieve O(1) performance (since the functions return hardcoded lists generated during compilation) while significantly reducing unnecessary boilerplate. Additionally, `public_aggregates/1` was added to ensure complete serialization.
