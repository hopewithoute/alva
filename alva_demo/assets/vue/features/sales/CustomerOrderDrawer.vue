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
  <Transition
    appear
    enter-active-class="transition-opacity duration-300 ease-out"
    enter-from-class="opacity-0"
    enter-to-class="opacity-100"
    leave-active-class="transition-opacity duration-200 ease-out"
    leave-from-class="opacity-100"
    leave-to-class="opacity-0"
  >
    <div
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      @click.self="emit('close')"
    >
      <Transition
        appear
        enter-active-class="transition-all duration-300 ease-out"
        enter-from-class="opacity-0 translate-y-4 scale-95"
        enter-to-class="opacity-100 translate-y-0 scale-100"
        leave-active-class="transition-all duration-200 ease-out"
        leave-from-class="opacity-100 translate-y-0 scale-100"
        leave-to-class="opacity-0 translate-y-4 scale-95"
      >
        <div class="w-full max-w-4xl border border-[var(--color-rule)] bg-[var(--color-paper)] shadow-2xl origin-center">
          <div class="flex items-start justify-between gap-4 border-b border-[var(--color-rule)] px-8 py-6">
            <div class="space-y-1">
              <p class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">Recent Orders</p>
              <h2 class="text-3xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display);">
                {{ connectedCustomerName || "Customer" }}
              </h2>
              <p class="text-sm text-[var(--color-ink-2)]">
                {{ recentOrderCount }} orders, {{ recentOrderItems }} items tracked.
              </p>
            </div>
            <Button size="sm" variant="secondary" class="btn--primary px-6 py-2 text-xs" @click="emit('close')">
              Close
            </Button>
          </div>

          <div class="grid gap-8 p-8 lg:grid-cols-[280px_minmax(0,1fr)]">
            <div class="space-y-2">
              <button
                v-for="order in customerOrders"
                :key="order.id"
                type="button"
                class="w-full border-b border-[var(--color-rule)] px-4 py-3 text-left transition-colors"
                :class="
                  selectedOrder?.id === order.id
                    ? 'border-[var(--color-ink)] bg-[var(--color-ink)] text-[var(--color-paper)]'
                    : 'border-[var(--color-rule)] bg-transparent hover:bg-[var(--color-paper-2)]'
                "
                @click="selectOrder(order.id)"
              >
                <div class="flex items-center justify-between gap-3">
                  <div class="font-normal text-base" style="font-family: var(--font-display)">
                    {{ order.product?.name || order.product_id }}
                  </div>
                  <span class="text-xs font-mono uppercase tracking-[0.1em]">
                    x{{ order.quantity }}
                  </span>
                </div>
                <p
                  class="mt-1 text-xs uppercase tracking-[0.1em]"
                  style="font-family: var(--font-mono)"
                  :class="selectedOrder?.id === order.id ? 'text-[var(--color-paper)] opacity-80' : 'text-[var(--color-ink-2)]'"
                >
                  {{ order.lifecycle_status }}
                </p>
              </button>
            </div>

            <div v-if="selectedOrder" class="border border-[var(--color-rule)] p-6 space-y-6">
              <div class="flex flex-wrap items-start justify-between gap-3 border-b border-[var(--color-rule)] pb-4">
                <div>
                  <p class="text-xs font-mono uppercase tracking-[0.1em] text-[var(--color-ink-2)]">Order Detail</p>
                  <h3 class="mt-1 text-3xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display);">
                    {{ selectedOrder.product?.name || selectedOrder.product_id }}
                  </h3>
                </div>
                <OrderStatusBadge :status="selectedOrder.lifecycle_status" />
              </div>

              <dl class="grid gap-6 sm:grid-cols-2">
                <div class="border-b sm:border-b-0 border-[var(--color-rule)] pb-4 sm:pb-0">
                  <dt class="text-xs font-mono uppercase tracking-[0.1em] text-[var(--color-ink-2)]">Customer</dt>
                  <dd class="mt-1 text-base font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">{{ selectedOrder.customer_name }}</dd>
                </div>
                <div>
                  <dt class="text-xs font-mono uppercase tracking-[0.1em] text-[var(--color-ink-2)]">Quantity</dt>
                  <dd class="mt-1 text-base font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">{{ selectedOrder.quantity }} item(s)</dd>
                </div>
                <div class="sm:col-span-2 pt-4 border-t border-[var(--color-rule)]">
                  <dt class="text-xs font-mono uppercase tracking-[0.1em] text-[var(--color-ink-2)]">What happens next</dt>
                  <dd class="mt-2 text-sm text-[var(--color-ink-2)]" style="line-height: 1.6;">
                    <span v-if="selectedOrder.lifecycle_status === 'new'">The merchant will see this order in the Merchant Console and can begin processing it.</span>
                    <span v-else-if="selectedOrder.lifecycle_status === 'processing'">The merchant is actively processing this order. Keep the support chat nearby if you need help.</span>
                    <span v-else>This order has been fulfilled and should now be complete.</span>
                  </dd>
                </div>
              </dl>
            </div>
          </div>
        </div>
      </Transition>
    </div>
  </Transition>
</template>
