Status: ready-for-agent

## What to build
Migrate the `Alva.LiveView` page events codegen to a pure AST extraction mechanism (such as a custom Mix compiler task). Currently, `.events.ts` files are written as a direct side-effect of `__using__` macro expansion. This is a fragile anti-pattern that can cause deadlocks or race conditions during parallel compilation. Refactor the implementation to parse the AST out of the `.ex` files during compilation without side-effects inside the macro.

## Acceptance criteria
- [ ] `Alva.LiveView` macro no longer writes files directly during expansion.
- [ ] A reliable extraction mechanism (e.g., Mix compiler task) generates the `.events.ts` files from the LiveView definitions.
- [ ] `CustomerStorefrontLive.events.ts` and `MerchantConsoleLive.events.ts` are still generated correctly upon compilation.
- [ ] Tests and builds pass without compilation deadlocks.

## Blocked by
None - can start immediately
