Status: ready-for-agent

## Parent
.scratch/alva-v2-streams/PRD.md

## What to build
Prove the V2 architecture by fully migrating the demo applications to the new setup.
1. Refactor `AlvaDemo.Catalog.Product`, removing the legacy `subscription` blocks and replacing them with `signal` and `event` boundaries.
2. Refactor `MerchantConsoleLive` and `CustomerStorefrontLive` to use the new `streams:` DSL in LiveView.
3. Update the frontend Vue components to use the new DX shape.
4. Refactor and clean up all E2E / integration tests in the demo app that relied on the legacy architecture, replacing them with accurate tests reflecting V2.

## Acceptance criteria
- [ ] `AlvaDemo.Catalog.Product` compiles perfectly with no legacy macros.
- [ ] LiveView pages correctly load SSR streams and execute dynamic signals.
- [ ] All old demo integration tests are cleaned up, rewritten, and passing (Seam 4).

## Blocked by
- .scratch/alva-v2-streams/issues/03-legacy-dsl-removal.md
