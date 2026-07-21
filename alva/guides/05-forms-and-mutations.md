# Forms and Mutations

This guide covers stateful form management, field validation, and Ash changeset error binding using `use_<action>_form`.

---

## 1. Overview & Conventions

Form mutations require managing field values, submit state, and server validation error responses.

* **Generated Form Composables:** `alva.<domain>.use_<action>_form({ initialValues })`.
* **Field Binding:** Field state is accessed via `form.field('<name>').value.value`.
* **Submission:** Form submit is executed via `await form.submit()`.

---

## 2. Ash Backend Definition

Define your update or create action in your Ash Resource:

```elixir
# lib/alva_demo/catalog/product.ex
defmodule AlvaDemo.Catalog.Product do
  use Ash.Resource,
    domain: AlvaDemo.Catalog,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Alva.Resource]

  alva do
    event(:catalog_adjust_stock, name: "catalog.adjust_stock", action: :adjust_stock)
  end

  actions do
    update :adjust_stock do
      public?(true)
      accept([:stock])
      validate numericality(:stock, greater_than_or_equal_to: 0)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :stock, :integer do
      allow_nil?(false)
      public?(true)
    end
  end
end
```

---

## 3. LiveView Integration

Mount `Alva.LiveView` in your LiveView module. `Alva.Dispatcher` validates changesets and maps invalid Ash errors directly into form response payloads:

```elixir
# lib/alva_demo_web/live/merchant_console_live.ex
defmodule AlvaDemoWeb.MerchantConsoleLive do
  use AlvaDemoWeb, :live_view
  use Alva.LiveView
end
```

---

## 4. Frontend TypeScript Library Usage

Use `alva.catalog.use_adjust_stock_form` inside your Vue component:

```vue
<script setup lang="ts">
import { ref } from "vue";
import { useAlva } from "@/js/alva";
import type { Product } from "@/js/alva/types";

const props = defineProps<{
  product: Product;
}>();

const alva = useAlva();

// Initialize generated form composable
const stockForm = alva.catalog.use_adjust_stock_form({
  initialValues: {
    id: props.product.id,
    stock: props.product.stock,
  }
});

const isAdjusting = ref(false);
const adjustmentError = ref<string | null>(null);

const adjustStock = async () => {
  const newStock = stockForm.field('stock').value.value ?? 0;
  if (newStock < 0 || isAdjusting.value) return;

  isAdjusting.value = true;
  adjustmentError.value = null;

  try {
    const result = await stockForm.submit();

    if (result.ok) {
      // Reset form errors and restore default values
      stockForm.reset();
    } else {
      adjustmentError.value = result.error?.message || "Failed to update stock.";
    }
  } catch (error: any) {
    adjustmentError.value = error.message || "Failed to update stock.";
  } finally {
    isAdjusting.value = false;
  }
};
</script>

<template>
  <form @submit.prevent="adjustStock" class="flex items-center gap-2">
    <input 
      type="number" 
      min="0" 
      class="w-20 border px-2 py-1 text-sm" 
      v-model="stockForm.field('stock').value.value" 
    />
    <button type="submit" :disabled="isAdjusting">
      {{ isAdjusting ? "Saving..." : "Update Stock" }}
    </button>
    <p v-if="adjustmentError" class="text-xs text-red-600">{{ adjustmentError }}</p>
  </form>
</template>
```
