Status: done

## Parent
`docs/prd.md` (Phase 8 - Forms Integration)

## What to build
Modify `Alva.Error` to handle complex Ash `sub_error` paths (e.g. from Embedded Resources or Dynamic Arrays). When Ash returns a validation error containing a `path` or `bread_crumbs` like `[:addresses, 0, :city]`, flatten it into a dot-notation string key (e.g., `"addresses.0.city"`). This ensures Vue forms using `ashForm` can correctly bind and display field-level errors for deeply nested structures.

## Acceptance criteria
- [x] `Alva.Error.format/1` accurately converts `path`/`bread_crumbs` into a dot-notated string key in the normalized `LiveError.fields` object.
- [x] Existing global conflicts (no field) are still correctly identified.
- [x] Simple top-level fields (like `:name`) are unaffected.
- [x] Verify functionality via ExUnit tests demonstrating embedded resource/array error formatting.

## Blocked by
None - can start immediately
