Status: ready-for-agent

## Parent

.scratch/alva-sdk-dx-overhaul/PRD.md

## What to build

Update the Elixir codegen (`alva/lib/alva/codegen/input_contract.ex` and `dto_generator.ex`) to explicitly expose Ash pagination and sort parameters in the generated TypeScript types. 

Specifically:
- Generate a `PaginationInput` interface (e.g., `{ limit?: number, offset?: number, ... }`).
- For `:read` actions, inject `page?: Types.PaginationInput` and `sort?: string | string[]` into the payload contract.

This is a prefactoring step that fixes missing type definitions without changing runtime behavior.

## Acceptance criteria

- [ ] `Types.PaginationInput` is generated in `types.ts`.
- [ ] Read actions in `events.ts` show `page?: Types.PaginationInput` and `sort?: string | string[]` in their `input` shape.
- [ ] `mix alva.codegen` runs successfully.

## Blocked by

None - can start immediately
