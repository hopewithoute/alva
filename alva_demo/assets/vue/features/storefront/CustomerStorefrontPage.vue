<script setup lang="ts">
import { computed } from "vue";
import StorefrontHeader from "../identity/StorefrontHeader.vue";
import StorefrontProductCard from "../catalog/StorefrontProductCard.vue";
import CustomerOrderDrawer from "../sales/CustomerOrderDrawer.vue";
import SupportChatWidget from "../support/SupportChatWidget.vue";
import { ref } from "vue";
import { useAlva, useAlvaAssigns } from "../../../js/alva";
import type { Order, Product, SupportMessage } from "../../../js/alva/types";

const props = defineProps<{
  sales_orders?: Order[];
  products?: Product[];
  active_conversation_id?: string | null;
  connected_customer_name?: string | null;
  support_messages?: SupportMessage[];
}>();

const isOrdersOpen = ref(false);
const orderError = ref<string | null>(null);
const orderNotice = ref<string | null>(null);
const orderDrawerRef = ref<any>(null);

const alva = useAlva();
const assigns = useAlvaAssigns();
const searchQuery = ref("");

const { data: queryProducts, loading: loadingProducts, error: queryError } = alva.catalog.use_list_products_query(
  () => ({ query: searchQuery.value }),
  { debounceMs: 300, autoRefreshOnSignal: "catalog.product_updated" }
);

const displayProducts = computed(() => {
  if (searchQuery.value.trim() === "") {
    return props.products;
  }
  return queryProducts.value ?? props.products;
});

const recentOrderCount = computed(() => props.sales_orders?.length || 0);
const recentOrderItems = computed(() => {
  if (!props.sales_orders) return 0;
  return props.sales_orders.reduce((sum, order) => sum + order.quantity, 0);
});

const handleOrderPlaced = (order: Order) => {
  orderNotice.value = `Order placed for this product. Open Recent Orders to track the status.`;
  orderError.value = null;
  isOrdersOpen.value = true;
  // Give it a moment to render before selecting
  setTimeout(() => {
    if (orderDrawerRef.value) {
      orderDrawerRef.value.selectOrder(order.id);
    }
  }, 100);
};

const handleOrderError = (error: string) => {
  orderError.value = error;
  orderNotice.value = null;
};
</script>

<template>
  <div class="grid gap-8 xl:grid-cols-[minmax(0,1fr)_360px]" data-testid="customer-storefront-vue">
    <section class="min-w-0 space-y-6">
      <StorefrontHeader
        :recentOrderCount="recentOrderCount"
        :recentOrderItems="recentOrderItems"
        :connected-customer-name="props.connected_customer_name"
        @open-orders="isOrdersOpen = true"
      />

      <div class="space-y-4">
        <div v-if="orderError" class="border border-[var(--color-danger-border)] bg-[var(--color-danger-surface)] p-3 text-sm text-[var(--color-danger)]">
          {{ orderError }}
        </div>
        <div v-if="orderNotice" class="border border-[var(--color-success-border)] bg-[var(--color-success-surface)] p-3 text-sm text-[var(--color-success)]">
          {{ orderNotice }}
        </div>
      </div>

      <div class="flex items-center gap-6 border-b border-[var(--color-rule)] pb-6 pt-2">
        <label class="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)] whitespace-nowrap" style="font-family: var(--font-mono)">Search Catalog</label>
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Type to search products..."
          class="flex-1 rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 py-2 text-sm text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0"
        />
        <div v-if="loadingProducts" class="text-xs text-[var(--color-ink-2)] italic" style="font-family: var(--font-display)">Searching...</div>
      </div>

      <div v-if="!displayProducts" class="border border-dashed border-[var(--color-rule)] p-6 text-sm text-[var(--color-ink-2)] italic" style="font-family: var(--font-display)">
        Loading catalog...
      </div>
      <div v-else class="grid grid-cols-1 gap-6 sm:grid-cols-2 2xl:grid-cols-3">
        <StorefrontProductCard
          v-for="product in displayProducts"
          :key="product.id"
          :product="product"
          :connected-customer-name="props.connected_customer_name"
          @order-placed="handleOrderPlaced"
          @order-error="handleOrderError"
        />
      </div>
    </section>

    <aside class="min-w-0">
      <SupportChatWidget
        :connected-customer-name="props.connected_customer_name"
        :active-conversation-id="props.active_conversation_id"
        :support-messages="props.support_messages"
      />
    </aside>

    <CustomerOrderDrawer
      v-if="isOrdersOpen"
      ref="orderDrawerRef"
      :customerOrders="props.sales_orders || []"
      :connected-customer-name="props.connected_customer_name"
      @close="isOrdersOpen = false"
    />
  </div>
</template>
