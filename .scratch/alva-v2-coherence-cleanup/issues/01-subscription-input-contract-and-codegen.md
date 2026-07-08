Status: done
Track: core-v2
PRD sequence: Step 1 - align generated subscription contracts with runtime truth

## PRD alignment

This is the foundational coherence slice. The V2 story depends on typed
subscriptions, but the generated contract currently overstates what callers must
provide compared with what resolvers actually derive from defaults, route state,
and nullable scope.

## What to build

Audit the subscription input contract seam across the DSL, codegen, and runtime
resolvers. Tighten `mix alva.codegen` so generated `AlvaSubscriptions` reflects
the real public caller contract for V2 subscriptions without changing behavior
casually.

Focus first on the active showcase resources:

- `alva_demo/lib/alva_demo/catalog/product.ex`
- `alva_demo/lib/alva_demo/sales/order.ex`
- `alva_demo/lib/alva_demo/support/conversation.ex`
- `alva_demo/lib/alva_demo/support/support_message.ex`
- `alva/lib/mix/tasks/alva.codegen.ex`

If `scope(...)` currently means "public input schema" rather than "all fields
that may exist after defaults and resolver merging", make that interpretation
explicit in code and tests.

## Acceptance criteria

- [x] Generated `AlvaSubscriptions` for showcase streams matches the actual
      allowed caller input instead of forcing fields that runtime derives or
      allows to be omitted.
- [x] Subscription codegen tests cover required vs optional vs nullable input
      cases for stream and signal capabilities.
- [x] Any runtime behavior change is surgical, explicit, and backed by tests;
      pure contract cleanup should not silently change resolver semantics.
- [x] The contract meaning of `scope(...)` is documented close to the owning
      seam so later slices do not have to infer it from generated output.

## Blocked by

- None - completed. Showcase-wide typed adoption can now treat the generated
  subscription contract as the owning input truth.
