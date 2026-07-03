Status: done

# Stream Query Binding for Pagination and Refresh

## Parent

.scratch/alva-phase-9-realtime/PRD.md

## What to build

Add page-level Stream Query bindings that apply command/read results to an active Route Collection using server-side Phoenix stream operations. This handles pagination and refresh flows without adding load-more behavior to the resource-level Stream Block.

A paginated or filtered command remains a normal command event. The page binding decides whether that command result should append, prepend, reset, or limit an active stream for that route.

## Acceptance criteria

- [x] A page can bind a command/read event result to an active Route Collection.
- [x] A Stream Query can prepend records into the active stream.
- [x] A Stream Query can append records into the active stream.
- [x] A Stream Query can reset the active stream for refresh/filter/search flows.
- [x] A Stream Query can preserve pagination feedback in the command reply meta.
- [x] Vue does not locally prepend/append/reset stream-owned collection data.
- [x] If the same command is invoked outside a Stream Query binding, it can still behave as a normal command/read result.

## Blocked by

- .scratch/alva-phase-9-realtime/issues/02-route-subscription-and-page-projection-activation.md
- .scratch/alva-phase-9-realtime/issues/03-pubsub-notification-to-active-route-collection.md
