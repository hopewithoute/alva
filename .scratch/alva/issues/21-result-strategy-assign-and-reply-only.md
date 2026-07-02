# 21 - Result Strategy: Assign and Reply Only

Status: ready-for-agent

## Parent

`docs/prd.md` (Phase 4 / Result Strategies)

## What to build

Extend the `Alva.Result` helper to support `{:assign, key}` and `{:reply, :data}` strategies. The `assign` strategy should bind the resulting data to the socket's assigns under the specified key, while `reply` simply acts as the default pass-through returning `{:reply, map, socket}` with no state mutations. Wire up dummy or test actions to verify these behaviors.

## Acceptance criteria

- [ ] Strategy `{:assign, key}` correctly calls `Phoenix.Component.assign/3` on the socket.
- [ ] Strategy `{:reply, :data}` correctly formats the return tuple without altering socket state.
- [ ] Tests verify that the socket's assigns are updated appropriately when using the assign strategy.

## Blocked by

- `.scratch/alva/issues/20-result-strategy-stream-delete-for-archive.md`
