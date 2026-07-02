# 20 - Result Strategy: Stream Delete for Archive

Status: done

## Parent

`docs/prd.md` (Phase 4 / Result Strategies)

## What to build

Extend the `Alva.Result` helper to support the `{:stream_delete, key}` strategy. Apply this strategy to the `students.archive` event in the demo application so that archived/destroyed student records are automatically removed from the `:students` stream on the client.

## Acceptance criteria

- [ ] Strategy `{:stream_delete, :students}` correctly calls `Phoenix.LiveView.stream_delete/3` on the socket.
- [ ] The `students.archive` event in the demo app is wired to use this strategy.
- [ ] Tests verify that the socket is correctly transformed with the stream delete operation.

## Blocked by

- `.scratch/alva/issues/19-result-strategy-stream-insert-for-create.md`
