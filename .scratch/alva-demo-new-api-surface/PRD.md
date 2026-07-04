Status: ready-for-agent

# Alva Demo New API Surface

## Context

The commerce showcase should demonstrate the current Alva API surface. Route-owned lists should use Alva Collections, declarative LiveView activation, and explicit `@streams.*` props instead of plain assigns plus stream-query workarounds.

Orders already use Collections. Products and conversations still use the older route stream/query setup, and support messages need an explicit route-state decision because their source depends on the selected conversation.

## Goals

- Use Collections for route-owned product, order, and conversation lists.
- Keep Vue props explicit at the render boundary.
- Remove obsolete DataSync list loading and stream-query workarounds once replaced.
- Preserve support chat, media upload, product images, validation, and existing seed behavior.

## Non-Goals

- Redesign the showcase UI.
- Change Ash resource business rules.
- Convert support messages to a Collection without first deciding how LiveView owns the selected conversation state.
