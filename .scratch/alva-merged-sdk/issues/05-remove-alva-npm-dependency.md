Status: done

## Parent
.scratch/alva-merged-sdk/PRD.md

## What to build
Remove the `alva` npm package dependency from the host app. The generated SDK should be self-contained and not import from `alva`. This includes:
- Updating the codegen to not generate `import { ... } from "alva"` statements
- Removing the `alva` package from the host app's `package.json`
- Updating any documentation that references the `alva` npm package

## Acceptance criteria
- [ ] The generated SDK does not import from `alva`
- [ ] The host app's `package.json` does not include `alva` as a dependency
- [ ] The generated composables are self-contained

## Blocked by
- Issue 01 (useAlvaApi generation)
- Issue 02 (ash.on generation)
- Issue 03 (useAlvaForm generation)
- Issue 04 (useAlvaUpload generation)
