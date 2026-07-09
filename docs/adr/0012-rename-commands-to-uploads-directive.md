# 12. Rename `commands:` to `uploads:` for Page-Level Activation

Date: 2026-07-10

## Status

Accepted

## Context

In Alva V2, the application-wide Global Registry allows standard events (imperative commands) dispatched from the Vue SDK to be routed directly to Ash Actions without page-level opt-in. The security boundary for these standard events is handled strictly by Ash Policies (`Ash.can?`), and dispatching them requires zero additional memory or socket allocation on the LiveView side.

However, file uploads are an exception. They require LiveView to explicitly call `allow_upload/3` during the `mount` lifecycle to allocate memory, track progress state, and open a WebSocket sub-channel or presigned S3 URL. If Alva were to auto-scan and globally activate `allow_upload` for every file-accepting action in the application on every page, it would lead to severe memory bloat and potential denial-of-service vulnerabilities.

To solve this, a page-level opt-in directive was introduced in the `use Alva.LiveView` macro. Unfortunately, it was named `commands: [...]`. 

This name created a leaky abstraction and severe vocabulary confusion:
1. It implied developers must list *all* commands they intend to use on the page, which is false and wastes CPU cycles.
2. It collided with the domain terminology where all active intent is a "Command", but only a subset require physical upload channel allocation.
3. In the Ash Resource DSL, these are just standard `event` declarations that happen to have `Ash.Type.File` arguments, which the system dynamically duck-types.

## Decision

We will rename the `commands: [...]` directive in the `use Alva.LiveView` macro to **`uploads: [...]`**.

- The `alva` DSL in the Ash Resource remains unchanged. An upload is simply an `event` that contains file arguments (duck typing).
- The LiveView macro directive explicitly signals memory/socket allocation: `use Alva.LiveView, streams: [...], uploads: [...]`.
- Standard commands (without files) do not need to be declared anywhere in the LiveView page.

## Consequences

- **Positive:** Restores the integrity of the Ubiquitous Language. Developers will no longer be misled into believing they must maintain a manual allowlist of standard commands on every page.
- **Positive:** Clearly communicates the physical memory cost of the directive (allocating upload channels).
- **Negative:** Requires a breaking change in the `Alva.LiveView` macro and migrating existing pages that used `commands:`.
