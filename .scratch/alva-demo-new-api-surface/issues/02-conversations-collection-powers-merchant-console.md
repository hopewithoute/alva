Status: done

# Conversations Collection Powers Merchant Console

## Parent

.scratch/alva-demo-new-api-surface/PRD.md

## What to build

Move the Merchant Console conversation list onto the new Alva Collection API surface end to end. New customer conversations should appear in the console through server-owned Collection updates, without manually refreshing or re-querying the route-owned conversation list.

## Acceptance criteria

- [x] Conversations are defined as an Alva Collection with an explicit source event and PubSub-backed insert operation.
- [x] Merchant Console activates the conversations Collection through declarative LiveView options or an equally explicit helper.
- [x] Merchant Console passes conversations to Vue from `@streams.conversations`, not from a plain list assign.
- [x] Creating or joining a support conversation makes it appear in Merchant Console without a manual list refresh.
- [x] Existing support conversation creation behavior remains intact.

## Blocked by

None - can start immediately
