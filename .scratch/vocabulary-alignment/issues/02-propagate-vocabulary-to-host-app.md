Status: ready-for-agent

## Parent

Blocked by `.scratch/vocabulary-alignment/issues/01-rename-commands-to-uploads-macro.md`

## What to build

Propagate the new domain vocabulary to the host application (e.g. AlvaDemo) that consumes the `alva` library.
The library was updated in Issue 01 to use `uploads:` instead of `commands:`, and in a previous refactor, the Ash Resource DSL was renamed from `live_vue do` to `alva do`. 
The host application must be updated to match so that it continues to compile and function correctly.

Scan the `/lib/` directory of the host application (outside of `/alva/`) for any lingering usages of `commands: [...]` in LiveView modules and `live_vue do` in Ash Resource modules. Replace them with `uploads: [...]` and `alva do` respectively.

## Acceptance criteria

- [ ] All instances of `commands: [` inside `use Alva.LiveView` across the host app are replaced with `uploads: [`.
- [ ] All instances of `live_vue do` across the host app's Ash Resources are replaced with `alva do`.
- [ ] `mix compile` succeeds at the root of the host application (`/var/www/ash_vue`).

## Blocked by

- `.scratch/vocabulary-alignment/issues/01-rename-commands-to-uploads-macro.md`
