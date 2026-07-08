Status: done

## What to build
Finish the test suite for `Alva.LiveView` by covering user-triggered events (`handle_event`). This slice focuses on actions like "alva:execute_command", "alva:validate", pagination loading ("alva:load_more"), and complex LiveView file upload life cycles, while strictly purging any legacy V1 codepaths encountered in these functions.

## Acceptance criteria
- [x] Complete test coverage for all `handle_event` variations in `lib/alva/live_view.ex`.
- [x] Test coverage for the file upload lifecycle functions (`allow_upload`, consuming uploads).
- [x] Audit the event handlers to remove any leftover V1 surfaces.
- [x] Overall project coverage reaches 100% via `mix coveralls`.

## Blocked by
- .scratch/test-coverage-100/issues/03-liveview-mount-info.md
