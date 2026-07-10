# Getting Started with Alva SDK

Alva provides a fully typed, auto-generated TypeScript SDK for Vue 3 that seamlessly bridges your Vue frontend with your Elixir/Ash backend via Phoenix LiveView.

## The Single Entry Point

The entire SDK surface is accessed through a single entry point: `useAlva()`. This function returns a deeply nested, domain-driven object that matches your backend Ash domains and resources.

```typescript
import { useAlva } from "@/alva";

// Initialize the SDK
const alva = useAlva({
  // Global config for handling responses
  onSuccess: (data, event) => console.log(`Success on ${event}`, data),
  onError: (error, event) => console.error(`Error on ${event}`, error)
});
```

## Domain-Driven Architecture

The SDK is organized by Domain -> Action. If you have an Ash domain named `Catalog` and a resource `Product` with an action `create_product`, it will be available under `alva.catalog.create_product`.

The SDK provides different patterns depending on your use case:

1. **Direct Actions** (`alva.domain.action`): Fire-and-forget or async/await server calls.
2. **Queries** (`alva.domain.use_action_query`): Reactive data fetching for `:read` actions.
3. **Forms** (`alva.domain.use_action_form`): Stateful form management with validation.
4. **Signals** (`alva.domain.on_signal`): Real-time PubSub subscriptions.
5. **Uploads** (`alva.use_upload`): File upload management.

Read the subsequent guides to learn how to use each feature pattern effectively.
