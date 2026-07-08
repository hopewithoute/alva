Status: ready-for-agent
Track: core-v2
PRD sequence: Step 3 - narrow the generated signal story to the supported V2 path

## PRD alignment

V2 teaches `useAlvaSignal` as the primary signal lifecycle wrapper, but the
generated client and related tests still promote `api.on` / `ash.on` style
usage. This slice reduces that split without forcing a broad runtime removal.

## What to build

Decide and implement the supported generated-client story for signal handling.
The default recommendation should line up with the V2 bridge-first path:

- commands through `useAlvaApi` / generated `ashCall`
- signals through `useAlvaSignal`

Compatibility retention is acceptable, but compat surface should stop being the
generated or documented default if it conflicts with the supported V2 path.

Owning seams include:

- `alva/assets/js/useAlvaApi.ts`
- `alva/lib/mix/tasks/alva.codegen.ex`
- `alva_demo/assets/js/alva/client.ts`
- `alva/test/mix/tasks/alva_codegen_test.exs`

## Acceptance criteria

- [ ] Generated client output no longer presents `.on` as the primary V2 signal
      path when `useAlvaSignal` is the supported wrapper.
- [ ] If `useAlvaApi().on` remains for compatibility, its role is clearly
      demoted rather than taught as the main path.
- [ ] Codegen and JS tests lock the chosen behavior so future slices do not
      reintroduce the split by accident.
- [ ] Command ergonomics (`ashCall`, `createAlvaApi().call`) remain unchanged.

## Blocked by

- `02-showcase-typed-subscription-adoption.md`
