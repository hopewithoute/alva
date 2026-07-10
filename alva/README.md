# Alva

<p align="center">
  <img src="guides/alva.png" width="250" alt="Alva Logo">
</p>

**Alva** (Ash Live Vue Adapter) is a fully typed, auto-generated TypeScript SDK for Vue 3 that seamlessly bridges your Vue frontend with your Elixir/Ash backend via Phoenix LiveView.

Alva eliminates the need for manual API routing, REST endpoints, or GraphQL resolvers. By directly connecting Ash Resources to LiveVue, Alva lets you execute actions, read streams, process uploads, and listen to PubSub signals from the frontend — all with end-to-end TypeScript safety.

## Installation

Add `alva` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:alva, "~> 0.1.0"}
  ]
end
```

Then run `mix deps.get`.

## Quick Start

1. **Configure Ash Resources** with the `Alva.Resource` extension and define events:

   ```elixir
   defmodule MyApp.Catalog.Product do
     use Ash.Resource,
       extensions: [Alva.Resource]

     alva do
       event(:catalog_list_products,
         name: "catalog.list_products",
         action: :list
       )
     end

     actions do
       read :list do
         public?(true)
       end
     end
   end
   ```

2. **Inject `Alva.LiveView`** into your LiveView:

   ```elixir
   defmodule MyAppWeb.StorefrontLive do
     use MyAppWeb, :live_view
     use Alva.LiveView, streams: [...]
   end
   ```

3. **Run the code generator** to produce TypeScript bindings:

   ```bash
   mix alva.codegen
   ```

4. **Use the generated SDK** in your Vue 3 frontend:

   ```typescript
   const alva = useAlva();
   const result = await alva.catalog.list_products({});
   ```

## Documentation

See the guides for detailed walkthroughs:

- [Getting Started](guides/01-getting-started.md)
- [Queries and Actions](guides/02-queries-and-actions.md)
- [Forms and Mutations](guides/03-forms-and-mutations.md)
- [Uploads](guides/04-uploads.md)
- [Signals](guides/05-signals.md)

Full API reference is available at [https://hexdocs.pm/alva](https://hexdocs.pm/alva).

