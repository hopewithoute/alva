# Alva Monorepo

<p align="center">
  <img src="alva/guides/alva.png" width="250" alt="Alva Logo">
</p>

Welcome to the Alva (Ash Live Vue Adapter) repository! This repository is structured as a monorepo containing the core package and a demo application.

## ✨ Features

- **End-to-End Type Safety**: Auto-generated TypeScript SDK ensures your Vue frontend stays perfectly in sync with your Ash backend.
- **Zero API Boilerplate**: Eliminates the need for manual API routing, REST endpoints, or GraphQL resolvers.
- **Auto-DTO**: Automatically gathers public fields during compile time to generate Data Transfer Objects (DTOs) and TypeScript definitions based on Ash Resource definitions and Field Policies.
- **Pure Server-Side Validation**: Leverages Ash's robust validation engine via debouncing, removing the need for client-side schemas (e.g., Zod or Valibot).
- **Integrated File Uploads**: Native integration with `ash_storage` via `useAlvaUpload` for seamless, zero-boilerplate file handling.
- **Realtime Reactivity**: Declarative synchronization of server-owned Phoenix LiveView streams to Vue props, and typed Signal listener callbacks for non-stream occurrences.
- **Secure by Default**: Requires explicit exposure of operations, enforces strict authorization, and implements environment-aware error redaction to prevent internal data leaks.

## 📦 Projects

- **[Alva Core (`/alva`)](./alva)**: A fully typed, auto-generated TypeScript SDK for Vue 3 that seamlessly bridges your Vue frontend with your Elixir/Ash backend via Phoenix LiveView. Check out the [Core README](./alva/README.md) for installation and usage.
- **[Alva Demo (`/alva_demo`)](./alva_demo)**: A demonstration application showing how to integrate and use Alva in a real-world scenario.

## 📚 Documentation

See the [guides](./alva/guides) inside the core package for detailed walkthroughs:
- [Getting Started](./alva/guides/01-getting-started.md)
- [Queries and Actions](./alva/guides/02-queries-and-actions.md)
- [Forms and Mutations](./alva/guides/03-forms-and-mutations.md)
- [Uploads](./alva/guides/04-uploads.md)
- [Signals](./alva/guides/05-signals.md)

Full API reference is available at [https://hexdocs.pm/alva](https://hexdocs.pm/alva).
