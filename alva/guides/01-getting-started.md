# Getting Started with Alva SDK

This end-to-end tutorial guides you step-by-step from zero to a fully working Alva application in under 10 minutes.

---

## Prerequisites

* Elixir 1.15+ and Phoenix 1.7+
* [LiveVue](https://github.com/livevue/livevue) installed and configured in your Phoenix project
* Ash Framework 3.0+

---

## Step 1: Install Dependencies

Add `:alva` to your `mix.exs` dependencies:

```elixir
# mix.exs
def deps do
  [
    {:alva, "~> 0.1.0"},
    {:live_vue, "~> 0.3.0"}
  ]
end
```

Fetch the new dependency:

```bash
mix deps.get
```

---

## Step 2: Register Application Domains

Configure your application's Ash domains in `config/config.exs`. At runtime, Alva uses this registry to discover events, validate authorization, and route WebSockets:

```elixir
# config/config.exs
config :my_app,
  ash_domains: [
    MyApp.Catalog
  ]
```

---

## Step 3: Define Ash Domain & Resource

Extend your Ash Domain with `Alva.Domain` and your Ash Resource with `Alva.Resource`:

### 3.1 Define Ash Domain

```elixir
# lib/my_app/catalog.ex
defmodule MyApp.Catalog do
  use Ash.Domain,
    extensions: [Alva.Domain]

  resources do
    resource MyApp.Catalog.Product
  end
end
```

### 3.2 Define Ash Resource & Alva Events

Expose resource actions to the frontend using the `alva do ... end` block:

```elixir
# lib/my_app/catalog/product.ex
defmodule MyApp.Catalog.Product do
  use Ash.Resource,
    domain: MyApp.Catalog,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Alva.Resource]

  alva do
    event(:catalog_list_products, name: "catalog.list_products", action: :list)
    event(:catalog_adjust_stock, name: "catalog.adjust_stock", action: :adjust_stock)
  end

  actions do
    defaults([:destroy])

    read :list do
      public?(true) # Mandatory: exposed actions must be public
    end

    update :adjust_stock do
      public?(true)
      accept([:stock])
      validate numericality(:stock, greater_than_or_equal_to: 0)
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

---

## Step 4: Generate TypeScript SDK

Run the Alva code generator to analyze your registered domains and build strongly-typed TypeScript interfaces and Vue composables:

```bash
mix alva.codegen
```

This outputs your SDK directly into `assets/js/alva/`:
* `assets/js/alva/types.ts`: TypeScript interfaces for Ash structs
* `assets/js/alva/events.ts`: Input and payload type definitions
* `assets/js/alva/index.ts`: Unified `useAlva()` composable

---

## Step 5: Create Phoenix LiveView

Inject `Alva.LiveView` into your LiveView module to manage process memory and sync real-time streams over WebSockets:

```elixir
# lib/my_app_web/live/storefront_live.ex
defmodule MyAppWeb.StorefrontLive do
  use MyAppWeb, :live_view

  use Alva.LiveView,
    streams: [
      products: [
        resource: MyApp.Catalog.Product,
        source: :list,
        sync_on: [:adjust_stock, :destroy]
      ]
    ]

  def render(assigns) do
    ~H"""
    <.vue
      id="storefront-page"
      v-component="StorefrontPage"
      v-inject="layout"
      v-socket={@socket}
      products={Map.get(@streams, :products)}
    />
    """
  end
end
```

---

## Step 6: Add Phoenix Route

Register your LiveView in `lib/my_app_web/router.ex`:

```elixir
# lib/my_app_web/router.ex
scope "/", MyAppWeb do
  pipe_through :browser

  live "/storefront", StorefrontLive
end
```

---

## Step 7: Build Vue 3 Component

Import `useAlva()` inside your Vue 3 component to interact with your Elixir backend:

```vue
<!-- assets/vue/StorefrontPage.vue -->
<script setup lang="ts">
import { ref } from "vue";
import { useAlva } from "@/js/alva";
import type { Product } from "@/js/alva/types";

const props = defineProps<{
  products?: Product[];
}>();

const alva = useAlva();
const searchQuery = ref("");

// Reactive search query
const { data: searchResults, loading } = alva.catalog.use_list_products_query(
  () => ({ query: searchQuery.value }),
  { debounceMs: 300 }
);

// Stock adjustment form
const selectedProduct = ref<Product | null>(null);
const stockForm = alva.catalog.use_adjust_stock_form({
  initialValues: {
    id: selectedProduct.value?.id || "",
    stock: selectedProduct.value?.stock || 0
  }
});

async function handleUpdateStock(product: Product) {
  selectedProduct.value = product;
  stockForm.field("id").value.value = product.id;
  stockForm.field("stock").value.value = product.stock + 5;
  
  const result = await stockForm.submit();
  if (result.ok) {
    console.log("Stock updated successfully!");
  }
}
</script>

<template>
  <div class="p-8 max-w-4xl mx-auto space-y-6">
    <h1 class="text-2xl font-bold">Storefront Catalog</h1>

    <input 
      v-model="searchQuery" 
      placeholder="Search products..." 
      class="border p-2 w-full rounded"
    />

    <div v-if="loading">Searching...</div>

    <div v-else class="space-y-4">
      <div 
        v-for="product in (searchResults || props.products)" 
        :key="product.id"
        class="border p-4 flex items-center justify-between rounded shadow-sm"
      >
        <div>
          <h3 class="font-semibold text-lg">{{ product.name }}</h3>
          <p class="text-sm text-gray-600">Stock: {{ product.stock }}</p>
        </div>

        <button 
          @click="handleUpdateStock(product)"
          class="bg-blue-600 text-white px-4 py-2 rounded text-sm hover:bg-blue-700"
        >
          Add 5 Stock
        </button>
      </div>
    </div>
  </div>
</template>
```

---

## Verification

Start your Phoenix server:

```bash
mix phx.server
```

Navigate to `http://localhost:4000/storefront` in your browser. Your Vue 3 component is now live, consuming stream data, executing reactive queries, and mutating stock levels over Phoenix LiveView WebSockets!
