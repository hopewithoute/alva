Status: DONE

## Parent

This issue was spawned from the DX architectural refactor (ADR 0008).

## What to build

Refactor `Alva.LiveView` macro and code generation to use Elixir-native type maps instead of raw TypeScript strings for `page_events`. This ensures runtime validation and reliable code generation.

## Acceptance criteria

- [ ] `Alva.LiveView` is updated so `page_events` accepts inputs like `%{customer_name: :string}` instead of string types.
- [ ] `Alva.LiveView` performs runtime casting/validation of incoming payloads against these types before calling the event handler function.
- [ ] `mix alva.codegen` is updated to generate correct TypeScript signatures based on the Elixir type map.
- [ ] All existing `page_events` in `CustomerStorefrontLive` and `MerchantConsoleLive` are migrated to the new type format.
- [ ] The generated `.events.ts` files compile successfully and match the expected types.

## Blocked by

None - can start immediately
