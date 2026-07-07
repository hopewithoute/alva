Status: done

## What to build

Build the foundational registry that stores `subscription` declarations and exposes them to TypeScript. Define the `subscription do ... end` macro in Elixir and compile it into a Global Topic Map. Update the `mix alva.gen.ts` code generator to output the `AlvaSubscriptions` interface, bridging payload types and Vue Prop interfaces.

## Acceptance criteria

- [ ] Elixir `subscription do ... end` macro parses and stores metadata.
- [ ] Global Topic Map registry is available at runtime.
- [ ] Codegen outputs `AlvaSubscriptions` type with Stream Props and Signal Payloads.

## Blocked by

- 01-prefactor-v1-cleanup.md
