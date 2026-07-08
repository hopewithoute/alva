Status: done
Track: legacy-compatibility
PRD sequence: Outside the primary migration path; preferred compatibility mechanism while `page_events:` still exist

## PRD alignment

This is the preferred compatibility hardening for deprecated `page_events:`
codegen. Even with this infrastructure in place, the PRD still treats
`page_events:` as a demoted surface rather than the main v2 teaching path.

## What to build

Refactor the page events codegen to use robust compiled module reflection instead of fragile AST parsing. Introduce a `__alva_page_events__/0` reflection function injected by the `Alva.LiveView` macro. Update the Mix compiler task `Mix.Tasks.Compile.AlvaPageEvents` to run *after* regular compilation, scanning output `.beam` files to find and execute this reflection function. Update the host application's `mix.exs` to place `:alva_page_events` after `Mix.compilers()`. This ensures absolute reliability by avoiding manual evaluation of aliases, variables, or module attributes in an isolated context.

## Acceptance criteria

- [x] `Alva.LiveView` macro injects `__alva_page_events__/0` which returns the declared `page_events`.
- [x] `Mix.Tasks.Compile.AlvaPageEvents` iterates over compiled `.beam` files, safely invoking `__alva_page_events__/0` if it exists.
- [x] `alva_demo/mix.exs` runs `:alva_page_events` after the Elixir compiler.
- [x] Codegen no longer suppresses arbitrary parse errors and perfectly supports advanced Elixir syntax like module attributes.
- [x] Tests and builds compile cleanly without errors.

## Blocked by

None - can start immediately
