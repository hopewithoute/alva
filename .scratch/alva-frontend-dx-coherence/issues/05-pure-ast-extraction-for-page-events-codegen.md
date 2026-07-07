Status: complete

## What to build
Migrate the `Alva.LiveView` page events codegen to a pure AST extraction mechanism (such as a custom Mix compiler task). Currently, `.events.ts` files are written as a direct side-effect of `__using__` macro expansion. This is a fragile anti-pattern that can cause deadlocks or race conditions during parallel compilation. Refactor the implementation to parse the AST out of the `.ex` files during compilation without side-effects inside the macro.

## Acceptance criteria
- [x] `Alva.LiveView` macro no longer writes files directly during expansion.
- [x] A reliable extraction mechanism (e.g., Mix compiler task) generates the `.events.ts` files from the LiveView definitions.
- [x] `CustomerStorefrontLive.events.ts` and `MerchantConsoleLive.events.ts` are still generated correctly upon compilation.
- [x] Tests and builds pass without compilation deadlocks.

## Blocked by
None - can start immediately
