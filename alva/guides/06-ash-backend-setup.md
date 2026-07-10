# Ash Resource Backend Setup

To expose your Ash framework resources to the frontend via the Alva SDK, you configure your resources using the `Alva.Resource` extension. This maps Ash actions and PubSub notifications to frontend-facing events and signals.

## Basic Configuration

In your Ash Resource file (e.g., `lib/my_app/catalog/product.ex`), add `Alva.Resource` to your `extensions` list, and define your exposed events in the `alva do ... end` block.

```elixir
defmodule MyApp.Catalog.Product do
  use Ash.Resource,
    domain: MyApp.Catalog,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub], # Required for signals
    extensions: [Alva.Resource]

  pub_sub do
    module MyAppWeb.Endpoint
    prefix "product"
    
    # 1. Publish occurrences when actions run
    publish :update, ["updated"]
  end

  alva do
    # 2. Map Ash Actions to SDK Events
    event(:catalog_list_products, name: "catalog.list_products", action: :list)
    event(:catalog_create_product, name: "catalog.create_product", action: :create)
    
    # 3. Map PubSub Occurrences to SDK Signals
    signal(:product_updated_signal, 
      name: "catalog.product_updated", 
      authorize_with: :read, 
      # The "on" array listens for occurrences published by the pub_sub block
      on: ["updated"]
    )
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      public?(true) # Required for all mapped events
    end
  end
end
```

## Advanced Event Configuration

The `event` DSL supports several advanced configurations to control how the SDK interacts with the action:

- **`lookup` (atom):** The field to use for lookups (e.g. `:id`) when dispatching instance-level actions.
- **`expose_metadata` (list of atoms):** Extracts keys from the `__metadata__` map of the Ash result and exposes them to the frontend SDK's response object.
- **`enable_filter` (boolean):** If set to `true`, the generated TypeScript client will accept a strictly typed filter AST for `:read` actions, allowing the frontend to pass complex queries.
- **`validate_only` (boolean):** If `true`, the event will strictly run `Ash.Changeset` or `Ash.ActionInput` validation without actually persisting or executing the action. Useful for live form validations.

```elixir
  alva do
    event :advanced_list,
      name: "catalog.advanced_list",
      action: :list,
      enable_filter: true,
      expose_metadata: [:pagination_count]

    event :validate_creation,
      name: "catalog.validate_creation",
      action: :create,
      validate_only: true
  end
```

## Signals (PubSub Subscriptions)

The `signal` DSL exposes a reactive PubSub topic that Vue clients can subscribe to dynamically via `alva.domain.on_signal(...)`.

- **`name` (string):** The public name exposed to Vue clients (e.g., `"catalog.product_updated"`).
- **`authorize_with` (atom):** The Ash action to use with `Ash.can?` to authorize the subscription request. Alva ensures only permitted users can listen to the signal.
- **`on` (list):** The Ash PubSub occurrence keys (from your `pub_sub` block) that trigger this signal.
- **`expose_metadata` (list of atoms):** Like events, this exposes metadata in the signal payload.

## Security Considerations

1. **Only Public Actions**: Alva enforces that any action mapped via an `event` must have `public?(true)`.
2. **Actor Assignment**: Alva automatically injects the `current_user` (actor) and `current_tenant` (tenant) from your LiveView socket assigns into both *events* and *signal subscriptions*, preserving your existing Ash policies and permissions.
