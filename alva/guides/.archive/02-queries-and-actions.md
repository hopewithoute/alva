# Queries and Actions

This guide covers how to execute read queries and direct mutation actions using Alva SDK composables.

---

## 1. Overview & Conventions

Alva provides two distinct interaction patterns for reading and mutating data:

* **Reactive Queries (`use_<action>_query`):** Reactive data fetching composable for Ash `:read` actions. Automatically re-fetches when input reactive getters change, with built-in debouncing.
* **Direct Actions (`alva.<domain>.<action>`):** One-off async command execution for buttons, background tasks, or imperative workflow calls.

---

## 2. Ash Backend Definition

Define your read action with filtering arguments inside `AlvaDemo.Catalog.Product`:

```elixir
# lib/alva_demo/catalog/product.ex
defmodule AlvaDemo.Catalog.Product do
  require Ash.Query

  use Ash.Resource,
    domain: AlvaDemo.Catalog,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Alva.Resource]

  alva do
    event(:catalog_list_products, name: "catalog.list_products", action: :list)
    event(:catalog_adjust_stock, name: "catalog.adjust_stock", action: :adjust_stock)
  end

  actions do
    defaults([:destroy])

    read :list do
      public?(true)
      argument(:query, :string, allow_nil?: true)
      argument(:max_stock, :integer, allow_nil?: true)

      prepare(fn query, _context ->
        query
        |> Ash.Query.sort(name: :asc)
        |> filter_product_query(Ash.Query.get_argument(query, :query))
        |> filter_max_stock(Ash.Query.get_argument(query, :max_stock))
      end)
    end

    update :adjust_stock do
      public?(true)
      accept([:stock])
    end
  end

  defp filter_product_query(query, nil), do: query
  defp filter_product_query(query, search_term) when is_binary(search_term) do
    case String.trim(search_term) do
      "" -> query
      pattern ->
        require Ash.Expr
        Ash.Query.filter(query, Ash.Expr.expr(contains(name, ^pattern) or contains(description, ^pattern)))
    end
  end

  defp filter_max_stock(query, nil), do: query
  defp filter_max_stock(query, max_stock) do
    require Ash.Expr
    Ash.Query.filter(query, Ash.Expr.expr(stock <= ^max_stock))
  end
end
```

---

## 3. LiveView Integration

Query events and direct actions are routed over WebSockets via `Alva.Dispatcher` without needing manual `handle_event/3` functions:

```elixir
# lib/alva_demo_web/live/customer_storefront_live.ex
defmodule AlvaDemoWeb.CustomerStorefrontLive do
  use AlvaDemoWeb, :live_view
  use Alva.LiveView
end
```

---

## 4. Frontend TypeScript Library Usage

### 4.1 Reactive Search Query (`alva.catalog.use_list_products_query`)

```vue
<script setup lang="ts">
import { ref } from "vue";
import { useAlva } from "@/js/alva";

const alva = useAlva();
const searchQuery = ref("");

// Re-fetches automatically when `searchQuery` changes
const { data, loading, error, refetch } = alva.catalog.use_list_products_query(
  () => ({ query: searchQuery.value }),
  { debounceMs: 300 }
);
</script>

<template>
  <div>
    <input v-model="searchQuery" placeholder="Search..." />
    <div v-if="loading">Searching...</div>
    <div v-else-if="error" class="text-red-600">Query failed: {{ error.message }}</div>
    <ul v-else-if="data">
      <li v-for="product in data" :key="product.id">{{ product.name }}</li>
    </ul>
  </div>
</template>
```

### 4.2 Direct Imperative Action (`alva.sales.begin_processing`)

```vue
<script setup lang="ts">
import { ref } from "vue";
import { useAlva } from "@/js/alva";

const alva = useAlva();
const isProcessing = ref(false);
const errorMessage = ref<string | null>(null);

async function handleBeginProcessing(orderId: string) {
  isProcessing.value = true;
  errorMessage.value = null;

  const result = await alva.sales.begin_processing({ id: orderId });

  isProcessing.value = false;

  if (result.ok) {
    console.log("Order processing started!");
  } else {
    errorMessage.value = result.error?.message || "Failed to update order status.";
  }
}
</script>
```
