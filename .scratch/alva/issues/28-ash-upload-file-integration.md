# 28 - ashUpload (File Upload Integration)

Status: ready-for-agent

## Parent
`.scratch/alva/PRD.md` (Phase 6)

## What to build
A specialized wrapper integrating LiveVue's upload capabilities (`useLiveUpload`) tightly with `ash_storage`. It allows components to track file selection, upload progress, enforce limits, and sync file references with Ash actions during form submission.

## Acceptance criteria
- [ ] Implement `ashUpload` wrapped around LiveVue's upload primitives.
- [ ] Expose progress, upload errors, and selected files to the Vue template.
- [ ] Ensure seamless integration with `ashForm` for submitting uploaded file references to Ash actions.

## Blocked by
- Issue 27 (`ashForm`)
