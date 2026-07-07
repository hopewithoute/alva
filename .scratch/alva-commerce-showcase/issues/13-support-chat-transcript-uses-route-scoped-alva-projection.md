Status: done

# Support Chat Transcript Uses Route-Scoped Alva Projection

## Parent

.scratch/alva-commerce-showcase/PRD.md

## What to build

Replace the Support Chat transcript's plain assign, raw Phoenix PubSub, and manual history-plus-live merge path with a native Alva projection owned by the active Conversation page scope. The Customer Storefront and Merchant Console should both load history and receive live Support Messages through the same canonical server-owned transcript path, while keeping messages from other Conversations out of the active chat.

## Acceptance criteria

- [ ] Support Chat transcript history and live updates run through a native Alva projection scoped by the active Conversation.
- [ ] Customer Storefront and Merchant Console no longer keep the canonical transcript in plain `support_messages` assigns fed by raw Phoenix PubSub handlers.
- [ ] Vue chat surfaces no longer manually merge historical Support Messages with live transcript props for the canonical chat history.
- [ ] Messages from other Conversations never appear in the active transcript, and selected Conversation changes switch transcript scope cleanly.
- [ ] Tests cover transcript history load, live message delivery, Conversation switching, and cross-surface realtime visibility through the new native projection path.

## Blocked by

- .scratch/alva-commerce-showcase/issues/12-support-chat-conversation-selection-becomes-page-owned.md
