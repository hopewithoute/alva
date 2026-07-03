Status: done

## Parent
`.scratch/alva/issues/29-backend-architectural-completion.md`

## Task 34: Dispatcher Ash Storage Integration

**Description:** Update `Alva.Dispatcher.dispatch` to accept the LiveView `socket`. Prior to executing an Ash action, the dispatcher must cross-reference `socket.assigns.uploads` with the action's arguments and invoke `consume_uploaded_entries` to process incoming files. The resulting file references must be merged into the action parameters.

**Acceptance criteria:**
- [x] `Alva.Dispatcher.dispatch` signature updated to accept `socket`.
- [x] Automatically detects and consumes uploaded entries for arguments configured with file types.
- [x] Passes the consumed file paths/references to `Ash.run_action`.

**Verification:**
- [x] ExUnit tests assert that `consume_uploaded_entries` is called when the parameters and socket assign match an expected file upload.

**Dependencies:** Issue 33
**Estimated scope:** Medium
