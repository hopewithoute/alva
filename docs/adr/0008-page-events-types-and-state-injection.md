# Page Events Type Definitions and Vue State Injection

To resolve developer experience (DX) friction and type-safety gaps when integrating Ash, LiveView, and Vue, we have made two architectural decisions regarding the `Alva` framework:

1. **Elixir-Native Types for `page_events`**: 
   We decided to abandon raw TypeScript strings for input types (e.g., `%{input: "{ customer_name: string }"}`) in `use Alva.LiveView`. Instead, we will use Elixir-native type maps (e.g., `%{customer_name: :string}`). 
   - **Why**: This allows `Alva.LiveView` to cast and validate payloads at runtime before handlers are invoked. It also allows the `mix alva.codegen` task to generate TypeScript types programmatically without relying on brittle magic strings.

2. **Vue Context Injection (`usePageState`)**:
   We decided to abandon passing global page context (like `customer_name` or `active_conversation_id`) via manual props drilling and `watch` syncing. Instead, we will introduce a `usePageState()` composable.
   - **Why**: When LiveView pushes updated route parameters, relying on Vue components to manually `watch` prop updates during `ref` initialization proved highly error-prone. By using Vue's `provide/inject` reactivity (via `usePageState()`), any component deep in the tree can safely and automatically react to LiveView state changes without boilerplate.
