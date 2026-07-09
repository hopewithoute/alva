Status: ready-for-agent

## Parent
.scratch/alva-merged-sdk/PRD.md

## What to build
Update the demo apps to use the new generated SDK. This includes:
- Updating Vue components to import from `./alva/` instead of `'alva'`
- Updating the demo app's `package.json` to remove the `alva` dependency
- Testing that all demo app features work with the new generated SDK

## Acceptance criteria
- [ ] Demo app Vue components import from `./alva/`
- [ ] Demo app's `package.json` does not include `alva` as a dependency
- [ ] All demo app features work correctly
- [ ] No type errors in the demo app

## Blocked by
- Issue 05 (remove alva npm dependency)
