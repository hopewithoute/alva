Status: done

## Parent
`.scratch/alva/issues/29-backend-architectural-completion.md`

## Task 33: Alva.LiveView Macro

**Description:** Create the `Alva.LiveView` module containing a `__using__` macro. This macro must hook into LiveView's `mount` to dynamically call `allow_upload` for any exposed event arguments that require `ash_storage`. It must also provide a fallback `handle_event` that routes to `Alva.Dispatcher.dispatch`, and a fallback `handle_info` that intercepts `%Ash.Notifier.Notification{}` and issues a `push_event`.

**Acceptance criteria:**
- [x] `use Alva.LiveView` successfully compiles in a LiveView module.
- [x] `allow_upload` is automatically configured on `mount` for valid file arguments.
- [x] `handle_event` fallback correctly calls `Alva.Dispatcher`.
- [x] `handle_info` fallback correctly routes Ash notifications to Vue via `push_event`.

**Verification:**
- [x] `Phoenix.LiveViewTest` on a dummy module demonstrates successful mount, upload configuration, and PubSub message forwarding.

**Dependencies:** None
**Estimated scope:** Medium
