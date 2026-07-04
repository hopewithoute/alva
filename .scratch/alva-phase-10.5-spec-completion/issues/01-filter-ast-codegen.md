## What to build

Implement a native Filter AST generator in `Alva.Codegen.DtoGenerator` for events that specify `enable_filter: true`. 
The codegen must NOT use a generic `AshFilter<T>`. Instead, it must strictly map to Ash's type-specific filter operators (e.g., `StringFieldFilter`, `IntFieldFilter`) and generate a recursive `[Resource]Filter` interface for each resource to support deep relationship filtering.

## Acceptance criteria

- [ ] Generates reusable type-specific operator interfaces (e.g., `StringFieldFilter`, `IntFieldFilter`, `BooleanFieldFilter`).
- [ ] Generates a `[Resource]Filter` interface for resources involved in an `enable_filter: true` event.
- [ ] The `[Resource]Filter` interface maps scalar fields to their correct type-specific operator interface.
- [ ] The `[Resource]Filter` interface supports basic boolean logic (`and`, `or`, `not`).
- [ ] The `[Resource]Filter` interface supports recursive deep relationship filtering (e.g., `PostFilter` can filter by `author?: UserFilter`).
- [ ] Compilation succeeds without cyclic dependency errors in the generated TypeScript.

## Blocked by

None - can start immediately
