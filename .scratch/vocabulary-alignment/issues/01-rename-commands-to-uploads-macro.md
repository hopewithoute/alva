Status: ready-for-agent

## What to build

Update the `Alva.LiveView` macro in the library to reflect the new domain vocabulary decided in ADR 0012. 
Specifically, the directive `commands: [...]` is being renamed to `uploads: [...]` because its sole physical function is to allocate `allow_upload` WebSockets in LiveView. Normal commands route via the global registry and do not need page-level opt-in.

Rename all internal variables matching `commands` inside `alva/lib/alva/live_view.ex` (e.g., `configure_file_uploads_from_commands` should become `configure_file_uploads_from_uploads` or simply `configure_file_uploads`).
Update all tests in `alva/test/` to use `uploads:` instead of `commands:` to ensure the test suite passes.

## Acceptance criteria

- [ ] `alva/lib/alva/live_view.ex` accepts `uploads:` instead of `commands:` in `use Alva.LiveView`.
- [ ] Internal private functions in `alva/lib/alva/live_view.ex` are renamed to reflect `uploads`.
- [ ] All occurrences of `commands:` in `alva/test/` are updated to `uploads:`.
- [ ] `mix test` passes perfectly inside the `alva/` directory.

## Blocked by

None - can start immediately
