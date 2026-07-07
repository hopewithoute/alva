Status: done

# Product Media Upload Uses Native Alva Upload Dispatch

## Parent

.scratch/alva-commerce-showcase/PRD.md

## What to build

Move the Merchant Console Product Media flow onto a native Alva upload dispatch path so the page no longer owns the final "upload finished, now call the action" orchestration itself. Merchant staff should still see upload progress and error states in the Merchant Console, and a successful Product Media upload should still update the Product record and appear in the Customer Storefront without refresh.

## Acceptance criteria

- [ ] Merchant Console no longer relies on page-local upload completion watchers to decide when to dispatch the Product Media action.
- [ ] Alva exposes a reusable upload dispatch seam that can submit the Product Media action once the upload reference is ready.
- [ ] Upload progress and error states remain visible in the Merchant Console during the Product Media flow.
- [ ] A successful Product Media upload still updates the Product media reference and becomes visible in the Customer Storefront without manual refresh.
- [ ] Tests cover the reusable Alva upload dispatch behavior and the end-to-end Product Media flow through the showcase.

## Blocked by

None - can start immediately
