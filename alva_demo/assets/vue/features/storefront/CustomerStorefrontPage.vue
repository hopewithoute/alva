<script setup lang="ts">
import { ref, computed, watch } from "vue";
import StorefrontHeader from "../identity/StorefrontHeader.vue";
import StorefrontProductCard from "../catalog/StorefrontProductCard.vue";
import CustomerOrderDrawer from "../sales/CustomerOrderDrawer.vue";
import SupportChatWidget from "../support/SupportChatWidget.vue";

import type { Order, Product, SupportMessage } from "../../../js/alva/types";

const props = defineProps<{
  sales_orders?: Order[];
  products?: Product[];
  active_conversation_id?: string | null;
  connected_customer_name?: string | null;
  support_messages?: SupportMessage[];
}>();

const customerName = ref(props.connected_customer_name || "");
const isOrdersOpen = ref(false);
const orderError = ref<string | null>(null);
const orderNotice = ref<string | null>(null);
const orderDrawerRef = ref<any>(null);

watch(() => props.connected_customer_name, (newName) => {
  if (newName !== undefined && newName !== null && newName !== customerName.value) {
    customerName.value = newName;
  }
});

const recentOrderCount = computed(() => props.sales_orders?.length || 0);
const recentOrderItems = computed(() => {
  if (!props.sales_orders) return 0;
  return props.sales_orders.reduce((sum, order) => sum + order.quantity, 0);
});

const onIdentityChanged = (name: string) => {
  customerName.value = name;
  if (!name) {
    isOrdersOpen.value = false;
    orderNotice.value = null;
    orderError.value = null;
  }
};

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
        :customerName="customerName"
        :recentOrderCount="recentOrderCount"
        :recentOrderItems="recentOrderItems"
        @open-orders="isOrdersOpen = true"
        @identity-changed="onIdentityChanged"
      />

      <div class="space-y-4">
        <div v-if="orderError" class="rounded-md bg-red-50 p-3 text-sm text-red-700">
          {{ orderError }}
        </div>
        <div v-if="orderNotice" class="rounded-md bg-emerald-50 p-3 text-sm text-emerald-700">
          {{ orderNotice }}
        </div>
      </div>

      <div v-if="!props.products" class="rounded-xl border border-dashed border-zinc-200 bg-white p-6 text-sm text-zinc-500">
        Loading catalog...
      </div>
      <div v-else class="grid grid-cols-1 gap-6 sm:grid-cols-2 2xl:grid-cols-3">
        <StorefrontProductCard
          v-for="product in props.products"
          :key="product.id"
          :product="product"
          :customerName="customerName"
          @order-placed="handleOrderPlaced"
          @order-error="handleOrderError"
        />
      </div>
    </section>

    <aside class="min-w-0">
      <SupportChatWidget
        :customerName="customerName"
        :activeConversationId="props.active_conversation_id"
        :connectedCustomerName="props.connected_customer_name"
        :supportMessages="props.support_messages"
      />
    </aside>

    <CustomerOrderDrawer
      v-if="isOrdersOpen"
      ref="orderDrawerRef"
      :customerOrders="props.sales_orders || []"
      :customerName="customerName"
      @close="isOrdersOpen = false"
    />
  </div>
</template>
