# Frontend Composables API Reference

This reference guide provides a complete overview of all auto-generated Vue 3 composables provided by Alva V2 (`useAlvaQuery`, `useAlvaForm`, `use_<signal>_state`, `use_<action>_upload`, `use_<action>_by_id`).

---

## 1. Overview & Conventions

Alva generates strongly-typed Vue 3 composables directly from your Ash domain definitions into `assets/js/alva/`:

* **Namespace Access:** All domain events, queries, forms, uploads, and signal state getters are namespaced under `alva.<domain>` (e.g. `alva.catalog.use_list_products_query()`).
* **Auto-Cleanup:** Signal subscriptions and query timers automatically detach when Vue components unmount.
* **Result Envelope:** All direct actions and form submissions return `Promise<AlvaResult<T>>` containing `{ ok: true, data: T }` or `{ ok: false, error: AlvaError }`.

---

## 2. Ash Backend Setup

Ensure your Ash resources expose public actions and signals via the `alva do ... end` DSL:

```elixir
# lib/alva_demo/catalog/product.ex
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
    event(:catalog_list_products, name: "catalog.list_products", action: :list, lookup: :id, enable_filter: true)
    event(:catalog_adjust_stock, name: "catalog.adjust_stock", action: :adjust_stock)
    event(:catalog_upload_media, name: "catalog.upload_media", action: :upload_media)

    signal :catalog_product_updated do
      name("catalog.product_updated")
      authorize_with(:list)
    end
  end
end
```

---

## 3. LiveView Integration

Mount `Alva.LiveView` in your LiveView module:

```elixir
# lib/alva_demo_web/live/customer_storefront_live.ex
defmodule AlvaDemoWeb.CustomerStorefrontLive do
  use AlvaDemoWeb, :live_view
  use Alva.LiveView
end
```

---

## 4. Frontend Composables Reference

### 4.1 Reactive Queries (`useAlvaQuery`)

```ts
const { data, loading, error, refetch } = alva.<domain>.use_<action>_query(
  inputGetter: () => InputPayload,
  options?: {
    debounceMs?: number;           // Debounce reactive input changes (default: 0)
    pollIntervalMs?: number;       // Background periodic polling interval in ms
    autoRefreshOnSignal?: string;  // Auto-refetch query when signal fires over PubSub
  }
)
```

#### Code Example:
```vue
<script setup lang="ts">
import { ref } from "vue";
import { useAlva } from "@/js/alva";

const alva = useAlva();
const searchQuery = ref("");

// Re-fetches on search input changes, polls every 10s, and auto-refetches when products update!
const { data: products, loading, error, refetch } = alva.catalog.use_list_products_query(
  () => ({
    query: searchQuery.value,
    filter: { stock: { greater_than: 0 } }
  }),
  {
    debounceMs: 300,
    autoRefreshOnSignal: "catalog.product_updated"
  }
);
</script>
```

#### 4.1.1 Single-Record Lookup Query Helpers (`use_<action>_by_id`)

For read actions configured with lookups (e.g. `lookup: :id`), Alva generates dedicated single-record query helpers:

```ts
const productId = ref("product-123");

// Auto-fetches single Product object when `productId.value` changes!
const { data: product, loading, error } = alva.catalog.use_list_products_by_id(productId);
```

---

### 4.2 Form Handling (`useAlvaForm`)

```ts
const form = alva.<domain>.use_<action>_form({
  initialValues: FormValues,
  validateEvent?: string,          // Optional change validation event
  debounceMs?: number,             // Change validation debounce
  onOptimisticSubmit?: (values) => () => void, // Optimistic UI update with rollback
  uploads?: Record<string, { getFileReferences: () => string[] }>
})
```

#### Form Return Object (`form`):
* `values`: Reactive form values object.
* `errors`: Reactive field validation errors mapped from server Ash changesets (`form.errors.title`).
* `valid`: Boolean indicating if form has zero errors.
* `submit()`: Submits form and returns `Promise<AlvaResult<T>>`.
* `reset(newValues?)`: Restores initial form values, clears error maps, and sets `valid = true`.

#### Code Example:
```vue
<script setup lang="ts">
import { useAlva } from "@/js/alva";

const alva = useAlva();

const stockForm = alva.catalog.use_adjust_stock_form({
  initialValues: { id: "product-123", stock: 10 }
});

const submitStock = async () => {
  const result = await stockForm.submit();
  if (result.ok) {
    stockForm.reset(); // Restores initial values & clears error maps
  }
};
</script>
```

---

### 4.3 1-Line Reactive Signal State (`use_<signal>_state`)

```ts
const { data, latest, count, clear } = alva.<domain>.use_<signal>_state(input?)
```

#### Return Object:
* `data`: `Ref<Payload[]>` — Reactive array of all received signal payloads (newest first).
* `latest`: `Ref<Payload | null>` — Reactive reference to the most recent signal payload.
* `count`: `ComputedRef<number>` — Count of accumulated payloads.
* `clear()`: Clears accumulated signal state.

#### Code Example:
```vue
<script setup lang="ts">
import { useAlva } from "@/js/alva";

const alva = useAlva();

// Auto-subscribes on mount, detaches on unmount
const { data: notifications, latest, count, clear } = alva.demo_notifications.use_sent_state();
</script>

<template>
  <div>
    <h3>Notifications ({{ count }})</h3>
    <button @click="clear">Clear All</button>
    <ul>
      <li v-for="item in notifications" :key="item.id">
        {{ item.title }} - {{ item.severity }}
      </li>
    </ul>
  </div>
</template>
```

---

### 4.4 Domain File Uploads (`use_<action>_upload`)

```ts
const upload = alva.<domain>.use_<action>_upload(options?: {
  maxFiles?: number;
  maxSize?: number;
})
```

#### Code Example:
```vue
<script setup lang="ts">
import { useAlva } from "@/js/alva";

const alva = useAlva();
const upload = alva.catalog.use_upload_media_upload({ maxFiles: 1 });

const saveImage = async () => {
  const result = await upload.dispatch(async (ctx) => {
    return await alva.catalog.upload_media({
      id: "product-123",
      media: ctx.primaryReference
    });
  });
};
</script>
```
