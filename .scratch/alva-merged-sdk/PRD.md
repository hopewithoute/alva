# PRD: Merged Generated SDK

## Problem Statement

The current architecture has a split between the `alva` npm library (runtime composables + types) and the codegen output (types + thin client). This creates:
- Type drift between library and codegen (e.g., `AlvaResult<T>` mismatch)
- Two sources of truth for frontend behavior
- Hidden runtime dependency on the library

## Solution

Generate a complete, self-contained TypeScript SDK from the host app's registry. The codegen becomes the source of truth for all frontend types and composables. The `alva` npm package is removed.

## Architecture

```
alva (Elixir library)
  ├── lib/              → runtime: LiveView hooks, dispatcher, registry
  └── lib/codegen/      → build-time: generates TypeScript SDK

Host app
  ├── mix.exs           → depends on :alva
  ├── assets/js/alva/   → generated SDK (composables + types)
  │   ├── index.ts
  │   ├── types.ts
  │   ├── events.ts
  │   ├── signals.ts
  │   └── composables/
  │       ├── useAlvaApi.ts
  │       ├── ash.ts
  │       ├── useAlvaForm.ts
  │       └── useAlvaUpload.ts
  └── vue/              → imports from ./alva/, not from 'alva' npm
```

## Key Decisions (ADR 0011)

1. Generated codegen is the source of truth
2. Self-contained SDK (no alva npm runtime dependency)
3. Direct import from live_vue
4. Mix task trigger (`mix alva.codegen`)
5. Per-event composable methods (not generic)
6. Remove the alva npm package

## Success Criteria

- [ ] Host apps import from `./alva/`, not from `'alva'` npm
- [ ] Generated composables have per-event methods with full type safety
- [ ] No `AlvaResult<T>` duplication between library and codegen
- [ ] Demo apps work with the new generated SDK
- [ ] All existing tests pass
