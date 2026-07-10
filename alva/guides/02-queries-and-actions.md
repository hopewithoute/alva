# Queries and Actions

This guide covers how to read data reactively and execute simple one-off actions using the Alva SDK.

## Queries (Reactive Reading)

For every Ash `:read` action, the SDK generates a `use_[action]_query` hook. This hook provides reactive data fetching, loading states, and automatic refetching.

### Example: Fetching a List of Products

```vue
<script setup lang="ts">
import { useAlva } from "@/alva";

const alva = useAlva();

// The query is reactive. We pass a getter function for the input payload.
// If the input relies on reactive state (like pagination or filters), the query will re-fetch automatically.
const { data, loading, error, refresh } = alva.catalog.use_list_products_query(() => ({
  page: { limit: 10, offset: 0 },
  sort: ["+price"]
}));
</script>

<template>
  <div v-if="loading">Loading products...</div>
  <div v-else-if="error">Error: {{ error.message }}</div>
  <ul v-else>
    <li v-for="product in data" :key="product.id">
      {{ product.name }} - ${{ product.price }}
    </li>
  </ul>
  
  <button @click="refresh()">Refresh List</button>
</template>
```

## Direct Actions (One-off Executions)

When you need to execute an action without managing form state (like clicking a "Delete" button or triggering a background process), you can call the action directly. Direct actions return a Promise.

### Example: Deleting an Item

```vue
<script setup lang="ts">
import { ref } from "vue";
import { useAlva } from "@/alva";

const alva = useAlva();
const isDeleting = ref(false);

async function deleteProduct(productId: string) {
  isDeleting.value = true;
  
  try {
    const result = await alva.catalog.destroy_product({ id: productId });
    
    if (result.ok) {
      alert("Product deleted successfully!");
    } else {
      alert("Failed to delete product: " + result.error.message);
    }
  } finally {
    isDeleting.value = false;
  }
}
</script>

<template>
  <button :disabled="isDeleting" @click="deleteProduct('123')">
    Delete Product
  </button>
</template>
```
