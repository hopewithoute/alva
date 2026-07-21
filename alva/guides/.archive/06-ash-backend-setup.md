# Ash Backend Setup

This guide covers configuring Ash domains and resources using `Alva.Domain` and `Alva.Resource`.

---

## 1. Overview & Conventions

Alva uses Spark DSL extensions to expose Ash actions and signals to the frontend.

* **Domains:** Must add `extensions: [Alva.Domain]` to `use Ash.Domain`.
* **Resources:** Must add `extensions: [Alva.Resource]` to `use Ash.Resource`.
* **Public Enforcements:** Any action exposed via an `event` MUST have `public?(true)`.
* **Registry Resolution:** Host applications register Ash domains in `config/config.exs`.

---

## 2. Ash Backend Definition

```elixir
# 1. Domain Configuration (lib/alva_demo/catalog.ex)
defmodule AlvaDemo.Catalog do
  use Ash.Domain,
    extensions: [Alva.Domain]

  resources do
    resource AlvaDemo.Catalog.Product
  end
end

# 2. Resource Configuration (lib/alva_demo/catalog/product.ex)
defmodule AlvaDemo.Catalog.Product do
  use Ash.Resource,
    domain: AlvaDemo.Catalog,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub],
    extensions: [Alva.Resource]

  pub_sub do
    module(AlvaDemoWeb.Endpoint)
    prefix("product")
    publish(:adjust_stock, ["updated"])
  end

  alva do
    event(:catalog_list_products, name: "catalog.list_products", action: :list)
    event(:catalog_adjust_stock, name: "catalog.adjust_stock", action: :adjust_stock)

    signal :catalog_product_updated do
      name("catalog.product_updated")
      on(:adjust_stock)
      authorize_with(:list)
    end
  end

  actions do
    defaults([:destroy])

    read :list do
      public?(true)
    end

    update :adjust_stock do
      public?(true)
      accept([:stock])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :stock, :integer do
      allow_nil?(false)
      public?(true)
    end
  end
end
```

### DSL Reference

#### `event` entity:
* `name` (string, required): Global wire name for the event (e.g. `"catalog.list_products"`).
* `action` (atom, required): Corresponding Ash action name (e.g. `:list`).
* `lookup` (atom, optional): Attribute used for single-record lookups (e.g. `:id`).
* `enable_filter` (boolean, optional): Enables dynamic filtering on read queries.
* `validate_only` (boolean, optional): When true, executes changeset validation without persisting data.

#### `signal` entity:
* `name` (string, required): Global wire name for the PubSub signal (e.g. `"catalog.product_updated"`).
* `on` (atom or list, required): Ash action name(s) triggering the broadcast notification.
* `authorize_with` (atom, required): Read action used to verify actor authorization before streaming.

---

## 3. LiveView Integration

Configure host application domains in `config/config.exs`:

```elixir
# config/config.exs
config :alva_demo,
  ash_domains: [
    AlvaDemo.Catalog,
    AlvaDemo.Sales,
    AlvaDemo.Support,
    AlvaDemo.Demos
  ]
```

At compile time and runtime, `Alva.Registry` builds an application-wide event and signal map used by `Alva.LiveView` to route events over WebSockets.

---

## 4. Frontend TypeScript Library Usage

Run the code generator to produce type bindings and client composables:

```bash
mix alva.codegen
```

Outputs TypeScript contracts into `assets/js/alva/`:
* `types.ts`: Strongly typed interfaces for all Ash Resource attributes and structs.
* `events.ts`: Event parameter and payload definitions.
* `signals.ts`: Signal payload types and topic parameters.
* `index.ts`: The unified `useAlva()` composable.
