# Ash Resource Backend Setup

To expose your Ash framework resources to the frontend via the Alva SDK, you need to configure your resources using the `Alva.Resource` extension. This allows you to map specific Ash actions to frontend-facing events.

## Basic Configuration

In your Ash Resource file (e.g., `lib/my_app/catalog/product.ex`), add `Alva.Resource` to your `extensions` list, and define your exposed events in the `alva do ... end` block.

```elixir
defmodule MyApp.Catalog.Product do
  use Ash.Resource,
    domain: MyApp.Catalog,
    data_layer: Ash.DataLayer.Ets,
    # 1. Add the Alva extension
    extensions: [Alva.Resource]

  # 2. Expose specific actions to the Alva SDK
  alva do
    # Map the `:list` action to the "catalog.list_products" event
    event(:catalog_list_products, name: "catalog.list_products", action: :list)
    
    # Map the `:create` action to the "catalog.create_product" event
    event(:catalog_create_product, name: "catalog.create_product", action: :create)
    
    # Map the `:destroy` action to the "catalog.delete_product" event
    event(:catalog_delete_product, name: "catalog.delete_product", action: :destroy)
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      # Note: Only public actions are allowed to be mapped
      public?(true)
      argument(:query, :string, allow_nil?: true)
    end
    
    create :create do
      public?(true)
      accept([:name, :price])
    end
  end

  # ... attributes and other configurations
end
```

## How It Translates to the Frontend

When you run `mix alva.codegen`, the Alva Elixir library reads all `event/2` definitions across your resources.

For the configuration above, the generator will produce the following nested structure on the frontend:

```typescript
alva.catalog.use_list_products_query()
alva.catalog.use_create_product_form()
alva.catalog.create_product()
alva.catalog.delete_product()
```

## Security Considerations

1. **Only Public Actions**: Alva enforces that any action mapped via an `event` must have `public?(true)` configured in the `actions` block.
2. **Actor Assignment**: Alva automatically injects the `current_user` (actor) and `current_tenant` (tenant) from your LiveView socket assigns into the Ash action, preserving your existing Ash policies and permissions.
