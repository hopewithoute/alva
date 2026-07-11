<script setup lang="ts">
import { ref, watch, computed } from "vue";
import type { Order } from "../../../js/alva/types";
import OrderStatusBadge from "../../shared/ui/badge/OrderStatusBadge.vue";
import Button from "../../shared/ui/button/Button.vue";

const props = defineProps<{
  customerOrders: Order[];
  connectedCustomerName?: string | null;
}>();

const emit = defineEmits<{
  (e: "close"): void;
}>();

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
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
    @click.self="emit('close')"
  >
    <div class="w-full max-w-4xl rounded-2xl border border-[var(--color-rule)] bg-[var(--color-paper)] shadow-2xl">
      <div class="flex items-start justify-between gap-4 border-b border-[var(--color-rule)] px-6 py-5">
        <div>
          <p class="text-sm font-medium text-[var(--color-ink-2)]">Recent Orders</p>
          <h2 class="text-xl font-semibold text-[var(--color-ink)]" style="font-family: var(--font-display);">
            {{ connectedCustomerName || "Customer" }}
          </h2>
          <p class="mt-1 text-sm text-[var(--color-ink-2)]">
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
                ? 'border-[var(--color-ink)] bg-[var(--color-ink)] text-[var(--color-paper)]'
                : 'border-[var(--color-rule)] bg-[var(--color-paper)] hover:bg-[var(--color-rule)]'
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
              :class="selectedOrder?.id === order.id ? 'text-zinc-300' : 'text-[var(--color-ink-2)]'"
            >
              {{ order.lifecycle_status }}
            </p>
          </button>
        </div>

        <div v-if="selectedOrder" class="rounded-xl border border-[var(--color-rule)] bg-[var(--color-rule)]/60 p-5">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <p class="text-sm font-medium text-[var(--color-ink-2)]">Order Detail</p>
              <h3 class="mt-1 text-2xl font-semibold text-[var(--color-ink)]" style="font-family: var(--font-display);">
                {{ selectedOrder.product?.name || selectedOrder.product_id }}
              </h3>
            </div>
            <OrderStatusBadge :status="selectedOrder.lifecycle_status" />
          </div>

          <dl class="mt-6 grid gap-4 sm:grid-cols-2">
            <div class="rounded-lg border border-[var(--color-rule)] bg-[var(--color-paper)] p-4">
              <dt class="text-xs font-medium uppercase tracking-wide text-[var(--color-ink-2)]">Customer</dt>
              <dd class="mt-2 text-sm font-medium text-[var(--color-ink)]">{{ selectedOrder.customer_name }}</dd>
            </div>
            <div class="rounded-lg border border-[var(--color-rule)] bg-[var(--color-paper)] p-4">
              <dt class="text-xs font-medium uppercase tracking-wide text-[var(--color-ink-2)]">Quantity</dt>
              <dd class="mt-2 text-sm font-medium text-[var(--color-ink)]">{{ selectedOrder.quantity }} item(s)</dd>
            </div>
            <div class="rounded-lg border border-[var(--color-rule)] bg-[var(--color-paper)] p-4 sm:col-span-2">
              <dt class="text-xs font-medium uppercase tracking-wide text-[var(--color-ink-2)]">What happens next</dt>
              <dd class="mt-2 text-sm text-[var(--color-ink-2)]">
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
