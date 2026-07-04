Status: ready-for-agent

# Operate Order Lifecycle In Merchant Console

## What to build

Give merchant staff a Merchant Console view of Orders and the ability to advance the intentionally linear Order Lifecycle from `new` to `processing` to `fulfilled`. Invalid transitions should be rejected by the Ash action contract and surfaced through the Alva result path.

## Acceptance criteria

- [ ] The Merchant Console shows Orders in a way that makes their current Order Lifecycle status easy to inspect.
- [ ] Merchant staff can advance an Order from `new` to `processing`.
- [ ] Merchant staff can advance an Order from `processing` to `fulfilled`.
- [ ] Invalid Order Lifecycle transitions are rejected by the server-side action contract.
- [ ] The Merchant Console includes an Inventory Snapshot sufficient to support order operations without modeling warehouse management.
- [ ] Tests cover valid transitions, invalid transition rejection, Merchant Console rendering, and route-level behavior.

## Blocked by

- 03-place-orders-from-customer-storefront
