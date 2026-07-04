Status: ready-for-agent

# Support Chat Between Shopper And Merchant

## What to build

Add lightweight Support Chat between shoppers and merchant staff. A shopper's Customer Name should identify a Conversation, Support Messages should flow through Ash Resource actions and Alva commands, and new messages should appear realtime across Customer Storefront and Merchant Console.

## Acceptance criteria

- [ ] Conversation and SupportMessage resources support one lightweight Conversation per Customer Name.
- [ ] The Customer Storefront lets a shopper send a Support Chat message in their Conversation.
- [ ] The Merchant Console shows Conversations by Customer Name and lets merchant staff select one.
- [ ] Merchant staff can send a Support Message back to the shopper.
- [ ] New Support Messages appear realtime on the opposite surface through Alva Streams or Signals.
- [ ] Tests cover Customer Name scoping, customer message creation, merchant response, selected Conversation behavior, and realtime message visibility.
- [ ] The slice avoids helpdesk behavior such as ticket status, priority, assignment, SLA, tags, macros, or escalation.

## Blocked by

- 03-place-orders-from-customer-storefront
