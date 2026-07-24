# Phoenix LiveView Integration

This guide covers injecting `Alva.LiveView` streams and file uploads into Phoenix LiveView modules.

---

## 1. Overview & Conventions

`Alva.LiveView` connects Phoenix LiveView process state with Vue 3 components over WebSockets.

* **Allowed Configuration Keys:** `use Alva.LiveView` accepts ONLY `:streams` and `:uploads`.
* **Dynamic Scope Assigns:** Colon-prefixed scope values (e.g. `:customer_name`) dynamically map to keys in `socket.assigns`.
* **Stream Re-configuration:** `Alva.LiveView.reconfigure_streams(socket, params)` updates stream scope assigns on URL parameter changes.

---

## 2. Ash Backend Definition

Ensure your Ash resources define public `:read` actions for streaming and mutation actions for sync triggers:

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
  end

  attributes do
    uuid_primary_key(:id)

    attribute :customer_name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :quantity, :integer do
      allow_nil?(false)
      default(1)
      public?(true)
    end
  end

  relationships do
    belongs_to :product, AlvaDemo.Catalog.Product do
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

Mount `Alva.LiveView` in your LiveView module and configure your streams and uploads:

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
      ],
      products: [
        resource: AlvaDemo.Catalog.Product,
        source: :list,
        sync_on: [:adjust_stock, :upload_media]
      ]
    ]

  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Alva.LiveView.reconfigure_streams(params)}
  end

  def render(assigns) do
    ~H"""
    <.vue
      id="customer-storefront-page"
      v-component="CustomerStorefrontPage"
      v-inject="layout"
      v-socket={@socket}
      sales_orders={Map.get(@streams, :sales_orders)}
      products={Map.get(@streams, :products)}
    />
    """
  end
end
```

---

## 4. Frontend TypeScript Library Usage

In your Vue component, consume streams directly as typed props:

```html
<script setup lang="ts">
import { useAlvaAssigns } from "@/js/alva";
import type { Order, Product } from "@/js/alva/types";

// Access socket.assigns reactively without explicit HEEx prop lists!
const assigns = useAlvaAssigns();

const props = defineProps<{
  sales_orders?: Order[];
  products?: Product[];
}>();
</script>

<template>
  <div class="storefront-page">
    <h2>Welcome {{ assigns.connected_customer_name }}</h2>
    <h2>Recent Orders ({{ props.sales_orders?.length || 0 }})</h2>
    <ul>
      <li v-for="order in props.sales_orders" :key="order.id">
        Customer: {{ order.customer_name }} — Qty: {{ order.quantity }}
      </li>
    </ul>
  </div>
</template>
```
