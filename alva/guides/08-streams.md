# Real-Time Streams

This guide covers real-time collection streaming, dynamic scope assigns, and automatic mutation synchronization using Alva streams.

---

## 1. Overview & Conventions

Alva streams leverage Phoenix LiveView's stream engine to maintain large data collections without keeping full list payloads in server process memory.

* **Zero-Memory Server Footprint:** Streams append, update, or remove items on the client without storing collection state in LiveView assigns.
* **Automatic Mutation Sync (`sync_on`):** When specified Ash actions occur, Alva automatically syncs affected stream items to connected client Vue props.
* **Dynamic Scope Assigns:** Scope parameters prefixed with colons (e.g., `scope: %{customer_query: :connected_customer_name}`) dynamically read values from `socket.assigns`.
* **Route Lifecycle Sync:** `Alva.LiveView.reconfigure_streams(socket, params)` refreshes stream query parameters when URL parameters change.

---

## 2. Ash Backend Definition

Ensure your Ash resource exposes a `:read` action for initial stream loading and defines `alva` events for actions listed in `sync_on`:

```elixir
# lib/alva_demo/sales/order.ex
defmodule AlvaDemo.Sales.Order do
  require Ash.Query

  use Ash.Resource,
    domain: AlvaDemo.Sales,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Alva.Resource]

  alva do
    event(:sales_list_orders, name: "sales.list_orders", action: :list)
    event(:sales_create_order, name: "sales.create_order", action: :create)
    event(:sales_begin_processing, name: "sales.begin_processing", action: :begin_processing)
  end

  actions do
    defaults([:destroy])

    read :list do
      public?(true)
      argument(:customer_query, :string, allow_nil?: true)

      prepare(fn query, _context ->
        customer_query = Ash.Query.get_argument(query, :customer_query)

        query =
          if is_nil(customer_query) or customer_query == "" do
            Ash.Query.filter(query, false)
          else
            query
          end

        query
        |> Ash.Query.sort(created_at: :desc)
        |> Ash.Query.load(:product)
        |> filter_customer_query(customer_query)
      end)
    end

    create :create do
      primary?(true)
      public?(true)
      accept([:customer_name, :product_id, :quantity])
      change(load(:product))
    end

    update :begin_processing do
      public?(true)
      change(set_attribute(:lifecycle_status, :processing))
      change(load(:product))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :customer_name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :lifecycle_status, :atom do
      constraints(one_of: [:new, :processing, :fulfilled])
      default(:new)
      allow_nil?(false)
      public?(true)
    end
  end

  defp filter_customer_query(query, nil), do: query
  defp filter_customer_query(query, search_term) do
    require Ash.Expr
    Ash.Query.filter(query, Ash.Expr.expr(contains(customer_name, ^search_term)))
  end
end
```

---

## 3. LiveView Integration

Configure streams inside `use Alva.LiveView` in your Phoenix LiveView module:

```elixir
# lib/alva_demo_web/live/customer_storefront_live.ex
defmodule AlvaDemoWeb.CustomerStorefrontLive do
  use AlvaDemoWeb, :live_view

  use Alva.LiveView,
    streams: [
      sales_orders: [
        resource: AlvaDemo.Sales.Order,
        source: :list,
        scope: %{customer_query: :connected_customer_name},
        sync_on: [:create, :begin_processing, :fulfill]
      ]
    ]

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :connected_customer_name, "Alice")}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Alva.LiveView.reconfigure_streams(params)}
  end

  def render(assigns) do
    ~H"""
    <.vue
      id="customer-storefront-page"
      v-component="CustomerStorefrontPage"
      v-socket={@socket}
      sales_orders={Map.get(@streams, :sales_orders)}
    />
    """
  end
end
```

---

## 4. Frontend TypeScript Library Usage

Consume stream collections as typed reactive props inside your Vue 3 component:

```vue
<!-- assets/vue/CustomerStorefrontPage.vue -->
<script setup lang="ts">
import { computed } from "vue";
import type { Order } from "@/js/alva/types";

const props = defineProps<{
  sales_orders?: Order[];
}>();

const orderCount = computed(() => props.sales_orders?.length || 0);
</script>

<template>
  <div class="orders-stream-panel">
    <h3>Live Orders Stream ({{ orderCount }})</h3>

    <div v-if="orderCount === 0">No orders found for this customer.</div>

    <ul v-else class="divide-y">
      <li v-for="order in props.sales_orders" :key="order.id" class="py-3 flex justify-between">
        <div>
          <span class="font-bold">{{ order.customer_name }}</span>
          <span class="text-xs text-gray-500 ml-2">Status: {{ order.lifecycle_status }}</span>
        </div>
      </li>
    </ul>
  </div>
</template>
```
