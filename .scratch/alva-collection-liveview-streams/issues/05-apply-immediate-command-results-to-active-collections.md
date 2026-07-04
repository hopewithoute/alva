Status: ready-for-agent

# Apply Immediate Command Results to Active Collections

## Parent

.scratch/alva-collection-liveview-streams/PRD.md

## What to build

When a Vue command succeeds and its Ash action corresponds to a Collection operation, update the caller's active Collection immediately using the same native LiveView stream primitive that PubSub would use. The caller should see create/update/delete reflected without waiting for the PubSub echo, and the later echo should remain idempotent through LiveView/LiveVue stream identity behavior.

## Acceptance criteria

- [ ] A successful create command mapped to an active Collection insert updates the caller's `@streams` collection immediately.
- [ ] A successful update command mapped to an active Collection update updates the caller's existing stream item immediately.
- [ ] A successful delete/archive command mapped to an active Collection delete removes the caller's stream item immediately.
- [ ] PubSub echo after the immediate update does not duplicate DOM records.
- [ ] Failed command results do not mutate Collections.
- [ ] Existing command replies still return normalized success, validation, and error payloads to Vue.
- [ ] LiveView tests cover the exact Buy/create no-refresh scenario that previously required a page refresh.

## Blocked by

- .scratch/alva-collection-liveview-streams/issues/04-map-collection-operations-to-native-liveview-stream-primitives.md
