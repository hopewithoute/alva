# Extract Alva.Serializer for unified payload formatting
Status: ready-for-agent

## What to build
Extract payload serialization logic out of `Alva.Dispatcher` and into a new deep module called `Alva.Serializer`. This module will serve as a unified adapter to translate Ash records into JSON-friendly formats (stripping metadata, parsing dates, extracting exposed metadata).

The serializer must use a unified primitive options contract (e.g., `expose_metadata: [...]`) rather than relying on overloaded UI concepts like Signal or Event declarations.

## Acceptance criteria
- [ ] `Alva.Serializer` module is created and handles all payload serialization logic.
- [ ] `Alva.Dispatcher` delegates to `Alva.Serializer` instead of implementing `strip_and_extract_metadata` internally.
- [ ] `Alva.LiveView` relies on `Alva.Serializer` directly for formatting signal payloads, without routing through Dispatcher functions.
- [ ] The `Alva.Serializer` API accepts raw primitives (like `expose_metadata`) instead of Ash DSL structs.

## Blocked by
None - can start immediately
