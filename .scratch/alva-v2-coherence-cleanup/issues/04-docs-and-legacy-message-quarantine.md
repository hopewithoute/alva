Status: done
Track: core-v2
PRD sequence: Step 4 - quarantine legacy docs and public error copy

## PRD alignment

The runtime and showcase are much closer to V2 than some repo docs and fail
loud messages suggest. This final slice makes the teaching path match the
current supported surface without attempting a destructive compatibility purge.

## What to build

Audit and rewrite the remaining public-facing docs and fail-loud strings that
still steer readers toward older page-runtime or signal patterns.

Priority targets:

- `docs/prd.md`
- `docs/adr/0002-realtime-command-stream-signal-split.md`
- `docs/alva-demo-api-surface.md`
- `alva/lib/alva/live_view.ex`

Bring the repo to one clear message:

- main V2 path: `event`, `subscription`, `use Alva.LiveView, subscriptions: [...]`,
  `useAlvaApi`, `useAlvaStream`, `useAlvaSignal`
- legacy path: historical or compatibility reference only

## Acceptance criteria

- [x] Historical docs are clearly marked as historical or compatibility
      reference if they remain in-tree.
- [x] Main docs no longer mention removed or absent helpers as if they are part
      of the active public surface.
- [x] Public fail-loud copy in `Alva.LiveView` no longer nudges users toward
      pre-V2 concepts when the supported answer is `subscriptions:`.
- [x] Documentation and examples consistently point new readers to ADR 0009 and
      the bridge-first demo surface first.

## Blocked by

- `03-generated-client-surface-narrowing.md`
