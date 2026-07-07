<script setup lang="ts">
import { ref, watch, computed } from "vue";
import { usePageState } from "alva";
import type { Order } from "../../../js/alva/types";
import OrderStatusBadge from "../../shared/ui/badge/OrderStatusBadge.vue";
import Button from "../../shared/ui/button/Button.vue";

const props = defineProps<{
  customerOrders: Order[];
}>();

const emit = defineEmits<{
  (e: "close"): void;
}>();

const { connected_customer_name } = usePageState<{ connected_customer_name: string | null }>();

const selectedOrderId = ref<string | null>(null);

const recentOrderCount = computed(() => props.customerOrders.length);
const recentOrderItems = computed(() =>
  props.customerOrders.reduce((sum, order) => sum + order.quantity, 0)
);

const selectedOrder = computed(() => {
  if (!selectedOrderId.value) return props.customerOrders[0] ?? null;
  return props.customerOrders.find((order) => order.id === selectedOrderId.value) ?? props.customerOrders[0] ?? null;
});

const selectOrder = (orderId: string) => {
  selectedOrderId.value = orderId;
};

watch(
  () => props.customerOrders,
  (orders) => {
    if (orders.length === 0) {
      selectedOrderId.value = null;
      return;
    }
    if (!selectedOrderId.value || !orders.some((o) => o.id === selectedOrderId.value)) {
      selectedOrderId.value = orders[0].id;
    }
  },
  { immediate: true }
);

export interface CustomerOrderDrawerExpose {
  selectOrder: (orderId: string) => void;
}
defineExpose<CustomerOrderDrawerExpose>({ selectOrder });
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-zinc-950/45 p-4"
    @click.self="emit('close')"
  >
    <div class="w-full max-w-4xl rounded-2xl border border-zinc-200 bg-white shadow-2xl">
      <div class="flex items-start justify-between gap-4 border-b border-zinc-200 px-6 py-5">
        <div>
          <p class="text-sm font-medium text-zinc-500">Recent Orders</p>
          <h2 class="text-xl font-semibold text-zinc-950">
            {{ connected_customer_name || "Customer" }}
          </h2>
          <p class="mt-1 text-sm text-zinc-500">
            {{ recentOrderCount }} orders, {{ recentOrderItems }} items
            currently tracked in this showcase.
          </p>
        </div>
        <Button size="sm" variant="secondary" class="min-w-[88px]" @click="emit('close')">
          Close
        </Button>
      </div>

      <div class="grid gap-4 p-6 lg:grid-cols-[280px_minmax(0,1fr)]">
        <div class="space-y-2">
          <button
            v-for="order in customerOrders"
            :key="order.id"
            type="button"
            class="w-full rounded-xl border px-4 py-3 text-left transition-colors"
            :class="
              selectedOrder?.id === order.id
                ? 'border-zinc-900 bg-zinc-950 text-white'
                : 'border-zinc-200 bg-white hover:bg-zinc-50'
            "
            @click="selectOrder(order.id)"
          >
            <div class="flex items-center justify-between gap-3">
              <div class="font-medium">
                {{ order.product?.name || order.product_id }}
              </div>
              <span class="text-xs font-medium uppercase tracking-wide">
                x{{ order.quantity }}
              </span>
            </div>
            <p
              class="mt-2 text-xs"
              :class="selectedOrder?.id === order.id ? 'text-zinc-300' : 'text-zinc-500'"
            >
              {{ order.lifecycle_status }}
            </p>
          </button>
        </div>

        <div v-if="selectedOrder" class="rounded-xl border border-zinc-200 bg-zinc-50/60 p-5">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <p class="text-sm font-medium text-zinc-500">Order Detail</p>
              <h3 class="mt-1 text-2xl font-semibold text-zinc-950">
                {{ selectedOrder.product?.name || selectedOrder.product_id }}
              </h3>
            </div>
            <OrderStatusBadge :status="selectedOrder.lifecycle_status" />
          </div>

          <dl class="mt-6 grid gap-4 sm:grid-cols-2">
            <div class="rounded-lg border border-zinc-200 bg-white p-4">
              <dt class="text-xs font-medium uppercase tracking-wide text-zinc-500">Customer</dt>
              <dd class="mt-2 text-sm font-medium text-zinc-950">{{ selectedOrder.customer_name }}</dd>
            </div>
            <div class="rounded-lg border border-zinc-200 bg-white p-4">
              <dt class="text-xs font-medium uppercase tracking-wide text-zinc-500">Quantity</dt>
              <dd class="mt-2 text-sm font-medium text-zinc-950">{{ selectedOrder.quantity }} item(s)</dd>
            </div>
            <div class="rounded-lg border border-zinc-200 bg-white p-4 sm:col-span-2">
              <dt class="text-xs font-medium uppercase tracking-wide text-zinc-500">What happens next</dt>
              <dd class="mt-2 text-sm text-zinc-600">
                <span v-if="selectedOrder.lifecycle_status === 'new'">The merchant will see this order in the Merchant Console and can begin processing it.</span>
                <span v-else-if="selectedOrder.lifecycle_status === 'processing'">The merchant is actively processing this order. Keep the support chat nearby if you need help.</span>
                <span v-else>This order has been fulfilled and should now be complete.</span>
              </dd>
            </div>
          </dl>
        </div>
      </div>
    </div>
  </div>
</template>
