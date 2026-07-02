# 19 - Result Strategy: Stream Insert for Create

Status: done

## Parent

`docs/prd.md` (Phase 4 / Result Strategies)

## What to build

Create an `Alva.Result` (or `Alva.Handler`) helper that takes a dispatcher result and applies LiveView-specific side effects to the socket. This slice focuses on supporting `[strategy: {:stream_insert, key}]`.
Update the `students.create` event in the demo application (`AlvaDemoWeb.Alva`) to use this new helper so that newly created student records are automatically inserted into the `:students` stream.

## Acceptance criteria

- [ ] `Alva.Result` (or equivalent) module exists and can process successful create actions.
- [ ] Strategy `{:stream_insert, :students}` correctly calls `Phoenix.LiveView.stream_insert/3` on the socket.
- [ ] The `students.create` event in the demo app is wired to use this strategy.
- [ ] Tests verify that the socket is correctly transformed with the stream insert operation.

## Blocked by

None - can start immediately
