# Alva Commerce Showcase PRD

Status: ready-for-agent

## Problem Statement

The current `alva_demo` app has been cleaned of the old primitive demos, but it does not yet provide a realistic sample application for showcasing and testing Alva. The user needs a small, focused commerce sample that demonstrates Alva across the surfaces that matter: AshResource actions, LiveVue interaction, realtime streams and signals, support chat, and the upload handler path through `ash_storage`.

The sample must feel like a real application without becoming a full e-commerce system. It should lean on the Merchant Console while retaining enough Customer Storefront behavior to generate realistic operational events.

## Solution

Build an Alva Commerce Showcase with two primary surfaces:

- A Customer Storefront where shoppers enter a Customer Name, browse Products, place simple Orders, see their Order Lifecycle status, and use Support Chat.
- A Merchant Console where merchant staff monitor Orders, advance the linear Order Lifecycle, maintain the Inventory Snapshot, upload Product Media via `ash_storage`, and respond to Support Chat Conversations.

The application will use ETS-backed Ash resources for sample state, LiveVue for interactive surfaces, shadcn-vue for the UI component foundation, and Alva's dispatcher/stream/signal/upload integrations as the core behavior under test.

## User Stories

1. As a shopper, I want to open the Customer Storefront, so that I can interact with the sample as a customer.
2. As a shopper, I want to enter a Customer Name, so that my Orders and Conversations are distinguishable without creating an account.
3. As a shopper, I want to browse a small product catalog, so that I can place a realistic sample Order.
4. As a shopper, I want to see Product Media in the catalog, so that upload behavior is visible from the Customer Storefront.
5. As a shopper, I want to see product names, prices, descriptions, and stock availability, so that the catalog feels coherent.
6. As a shopper, I want to place an Order for a Product, so that the Merchant Console receives realtime operational data.
7. As a shopper, I want order submission to use Alva action dispatch, so that the sample tests the customer-facing event path.
8. As a shopper, I want to see my submitted Order, so that I can confirm the Customer Storefront state changed.
9. As a shopper, I want to see the Order Lifecycle status, so that merchant-side updates are visible to me.
10. As a shopper, I want the Order Lifecycle to remain simple, so that the sample is easy to understand.
11. As a shopper, I want to send a Support Chat message, so that I can ask merchant staff for help.
12. As a shopper, I want my Support Chat Conversation to be separate from other customers, so that multiple test users do not collide.
13. As a shopper, I want new Support Chat messages from merchant staff to appear realtime, so that the chat demonstrates Alva's realtime surface.
14. As merchant staff, I want to open the Merchant Console, so that I can operate the sample application.
15. As merchant staff, I want to see incoming Orders realtime, so that I can verify stream updates from the Customer Storefront.
16. As merchant staff, I want to see Orders grouped or filtered by status, so that the Order Lifecycle is easy to inspect.
17. As merchant staff, I want to advance an Order from `new` to `processing`, so that the sample tests an Ash update action.
18. As merchant staff, I want to advance an Order from `processing` to `fulfilled`, so that the sample tests a second state transition.
19. As merchant staff, I want invalid Order Lifecycle transitions to be prevented, so that the sample has a clear contract.
20. As merchant staff, I want Order updates to be reflected on the Customer Storefront, so that both surfaces prove realtime synchronization.
21. As merchant staff, I want to see an Inventory Snapshot, so that catalog state supports order operations without modeling warehouse management.
22. As merchant staff, I want to adjust product stock in a simple way, so that inventory changes can be tested through Alva actions.
23. As merchant staff, I want to upload Product Media for a Product, so that the sample exercises the `ash_storage` upload handler integration.
24. As merchant staff, I want uploaded Product Media to update the Product record, so that the image reference is visible across surfaces.
25. As merchant staff, I want uploaded Product Media to appear in the Customer Storefront catalog, so that the upload flow is end-to-end.
26. As merchant staff, I want upload progress and error states in the UI, so that the upload handler behavior can be inspected.
27. As merchant staff, I want the Merchant Console to show Support Chat Conversations by Customer Name, so that I can respond to the right customer.
28. As merchant staff, I want to select a Conversation, so that I can view its Support Messages.
29. As merchant staff, I want new customer Support Messages to appear realtime, so that the chat stream is visibly working.
30. As merchant staff, I want to send a Support Message back to the shopper, so that the two-sided Support Chat is testable.
31. As merchant staff, I want the Support Chat to remain lightweight, so that the sample does not become a helpdesk system.
32. As a developer, I want all core behavior to go through Ash resources, so that the sample tests Alva against the intended backend surface.
33. As a developer, I want sample state to use ETS instead of PostgreSQL, so that the app runs without database setup friction.
34. As a developer, I want the Product Media upload path to use `ash_storage`, so that the sample covers Alva's file upload support.
35. As a developer, I want LiveVue components to use shadcn-vue, so that the UI is polished while remaining Vue-native.
36. As a developer, I want codegen/client event contracts to be visible in the sample, so that Alva's typed frontend surface is easier to validate.
37. As a developer, I want seeded sample data, so that the Merchant Console and Customer Storefront are useful immediately after startup.
38. As a developer, I want the seed data to be resettable by restarting the app, so that demos begin from a predictable state.
39. As a developer, I want tests to exercise behavior through high-level seams, so that implementation details can evolve.
40. As a developer, I want a minimal domain model, so that the showcase stays focused on Alva rather than commerce completeness.

## Implementation Decisions

- The sample will use the glossary terms Customer Storefront, Merchant Console, Order Lifecycle, Inventory Snapshot, Product Media, Support Chat, Conversation, and Customer Name.
- The Customer Storefront and Merchant Console will be separate routes. The root route may remain a small entry surface that links to both.
- The app will lean on the Merchant Console as the primary showcase while keeping the Customer Storefront realistic enough to generate Orders and Conversations.
- Customer identity will be a shopper-provided Customer Name only. There will be no authentication, account model, profile, email verification, or authorization workflow.
- The Order Lifecycle is intentionally linear: `new -> processing -> fulfilled`.
- There will be no `cancelled`, `draft`, payment, refund, shipping carrier, discount, tax, or cart lifecycle.
- The initial resource set will be Product, Order, Conversation, and SupportMessage.
- Product owns Product Media directly. There will not be a separate ProductMedia resource unless implementation proves it is necessary for `ash_storage`.
- Product will contain enough catalog data for the showcase: name, description, price, stock, and media reference.
- Order will contain Customer Name, Product reference, quantity, and lifecycle status.
- Conversation will represent a support thread for one Customer Name.
- SupportMessage will belong to a Conversation and record sender identity and message body.
- ETS-backed Ash resources are the default storage mechanism for sample state.
- PostgreSQL and AshPostgres are not part of the showcase storage design.
- Product Media uploads are the deliberate exception to ephemeral resource state because they exist to test `ash_storage` and Alva upload handling.
- Seeded sample data should include products, orders in different lifecycle states, and support conversations with messages.
- Alva event names should be explicit and stable, for example products list/update/upload, orders list/create/start-processing/fulfill, conversations list/create/select, and support messages list/create.
- Merchant lifecycle actions should reject invalid transitions.
- Realtime updates should use Alva stream and signal projections rather than custom ad hoc client synchronization.
- LiveVue is the interactive UI bridge for both Customer Storefront and Merchant Console.
- shadcn-vue is the UI component foundation.
- Vite is the correct frontend bundler for LiveVue because the existing Vue entrypoint uses Vite-style module discovery.
- Phoenix templates that host LiveViews must use `<Layouts.app flash={@flash}>`.
- The implementation should avoid LiveComponents unless a specific need appears.
- The implementation should keep the UI polished but operational, not a marketing landing page.
- The existing clean baseline should stay clean: do not reintroduce old Student, Academics, Communication, primitive demo routes, or PostgreSQL migrations.

## Testing Decisions

- The preferred test seam is the highest route-level LiveView behavior seam: test `/shop` and `/console` from the user's perspective with Phoenix LiveView tests.
- Tests should assert stable DOM IDs and behavior outcomes rather than raw HTML text.
- Customer Storefront tests should verify catalog rendering, Customer Name capture, simple order creation, order status visibility, and customer-side Support Chat behavior.
- Merchant Console tests should verify order visibility, lifecycle advancement, invalid transition prevention, Product Media upload controls, Inventory Snapshot behavior, and merchant-side Support Chat behavior.
- Resource/action tests should cover contracts that are awkward to validate only through UI, especially lifecycle transition rules and upload action argument handling.
- Alva dispatcher tests should verify that core events route to the intended Ash actions and return public data only.
- Upload tests should verify that the Product upload action accepts file input through the Alva upload path and updates the Product media reference.
- Realtime behavior should be tested at a practical seam: one LiveView action should produce data visible to another surface, without testing PubSub internals.
- Existing prior art includes Phoenix controller tests, LiveView route tests, Alva dispatcher tests in the sibling Alva package, and the current `mix precommit` validation flow.
- The final implementation must pass `mix precommit`.
- The final implementation should pass `mix assets.build` because LiveVue/shadcn-vue integration depends on a healthy frontend build.

## Out of Scope

- Full storefront cart behavior.
- Customer accounts, authentication, authorization, or profile management.
- Payment, checkout, invoices, refunds, shipping labels, delivery tracking, taxes, discounts, coupons, or promotions.
- Warehouse management or full inventory accounting.
- Full helpdesk behavior such as ticket status, priority, assignment, SLA, tags, macros, or escalation.
- Durable database persistence for commerce sample state.
- PostgreSQL migrations for the commerce showcase.
- Separate Product Media management screens or a general media library.
- Mobile app flows beyond responsive web behavior.
- Production deployment hardening.

## Further Notes

- The old demo implementation has already been removed to keep the showcase implementation clean.
- The app currently has a clean placeholder root page and no commerce resources yet.
- The tracker for this PRD is local markdown under `.scratch/alva-commerce-showcase/`.
- This PRD is ready for implementation slicing into agent-ready issues.
