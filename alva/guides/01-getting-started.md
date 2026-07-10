# Getting Started with Alva SDK

Alva provides a fully typed, auto-generated TypeScript SDK for Vue 3 that seamlessly bridges your Vue frontend with your Elixir/Ash backend via Phoenix LiveView.

## Installation

Add `alva` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:alva, "~> 0.1.0"}
  ]
end
```

Then fetch the dependency:

```bash
mix deps.get
```

## Backend Setup

### 1. Configure Alva

Add Alva configuration to your application's `config.exs`:

```elixir
config :alva,
  output_dir: "assets/js/alva",
  actor_assign_key: :current_user,
  tenant_assign_key: :current_tenant
```

### 2. Extend Your Ash Resources

Add `Alva.Resource` as an extension to each Ash resource you want to expose:

```elixir
defmodule MyApp.Catalog.Product do
  use Ash.Resource,
    domain: MyApp.Catalog,
    extensions: [Alva.Resource]

  alva do
    event(:catalog_list_products,
      name: "catalog.list_products",
      action: :list
    )

    event(:catalog_create_product,
      name: "catalog.create_product",
      action: :create
    )
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      public?(true)
    end

    create :create do
      public?(true)
    end
  end
end
```

> All actions mapped via `event` must have `public?(true)`.

### 3. Inject Alva into Your LiveView

Add `use Alva.LiveView` to the LiveView that hosts your Vue component:

```elixir
defmodule MyAppWeb.StorefrontLive do
  use MyAppWeb, :live_view
  use Alva.LiveView, streams: [...]
end
```

### 4. Generate the TypeScript SDK

Run the code generator to produce typed frontend bindings:

```bash
mix alva.codegen
```

This outputs TypeScript files to `assets/js/alva/` (configurable via `output_dir`).

## Frontend Usage

Import the generated SDK in your Vue 3 component:

```typescript
import { useAlva } from "@/alva";
```

### The Single Entry Point

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
