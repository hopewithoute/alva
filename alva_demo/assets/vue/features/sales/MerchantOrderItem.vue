<script setup lang="ts">
import { computed, ref } from "vue";
import { useAlva } from "../../../js/alva";
import type { Order } from "../../../js/alva/types";
import OrderStatusBadge from "../../shared/ui/badge/OrderStatusBadge.vue";
import Button from "../../shared/ui/button/Button.vue";

const props = defineProps<{
  order: Order;
}>();

const alva = useAlva();
const pendingAction = ref<"begin_processing" | "fulfill" | null>(null);
const operationError = ref<string | null>(null);

const isLoading = computed(() => pendingAction.value !== null);

const orderActionLabel = computed(() => {
  if (pendingAction.value === "begin_processing") return "Processing...";
  if (pendingAction.value === "fulfill") return "Fulfilling...";
  if (props.order.lifecycle_status === "new") return "Begin Processing";
  if (props.order.lifecycle_status === "processing") return "Fulfill Order";
  return "Completed";
});

const hasOrderAction = computed(() => {
  return (
    props.order.lifecycle_status === "new" || props.order.lifecycle_status === "processing"
  );
});

const runOrderAction = async () => {
  if (isLoading.value) return;

  operationError.value = null;

  try {
    if (props.order.lifecycle_status === "new") {
      pendingAction.value = "begin_processing";

      const result = await alva.sales.begin_processing({ id: props.order.id });

      if (!result.ok) {
        operationError.value = result.error?.message || "Failed to begin processing order.";
      }
    } else if (props.order.lifecycle_status === "processing") {
      pendingAction.value = "fulfill";

      const result = await alva.sales.fulfill({ id: props.order.id });

      if (!result.ok) {
        operationError.value = result.error?.message || "Failed to fulfill order.";
      }
    }
  } catch (error: any) {
    operationError.value = error.message || "Failed to update order.";
  } finally {
    pendingAction.value = null;
  }
};

const getOrderProductName = () => {
  return props.order.product?.name ?? "Unknown Product";
};

const formatDateTime = (isoString: string) => {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(isoString));
};

</script>

<template>
  <div
    class="flex flex-col gap-4 border-b border-[var(--color-rule)] pb-6 pt-2 lg:flex-row lg:items-center lg:justify-between"
  >
    <div class="min-w-0 space-y-1">
      <div class="flex flex-wrap items-center gap-3">
        <p class="text-base text-[var(--color-ink)]" style="font-family: var(--font-display)">
          Order by
          <span class="font-semibold">{{ order.customer_name }}</span>
        </p>
        <span
          v-if="order.lifecycle_status === 'new'"
          class="border border-danger-border bg-danger-surface px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.1em] text-danger"
          style="font-family: var(--font-mono)"
        >
          New
        </span>
      </div>
      <p class="text-sm text-[var(--color-ink-2)]">
        {{ getOrderProductName() }} (Qty: {{ order.quantity }})
      </p>
      <p class="text-xs text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
        {{ formatDateTime(order.created_at) }}
      </p>
      <p v-if="operationError" class="text-xs text-danger italic" style="font-family: var(--font-display)">
        {{ operationError }}
      </p>
    </div>

    <div class="flex flex-wrap items-center gap-4 lg:justify-end">
      <OrderStatusBadge :status="order.lifecycle_status" />

      <div class="flex min-w-[140px] justify-end">
        <Button
          v-if="hasOrderAction"
          variant="secondary"
          size="sm"
          class="btn--primary min-w-[140px] py-2 text-xs"
          @click="runOrderAction"
          :disabled="isLoading"
        >
          {{ orderActionLabel }}
        </Button>
        <span
          v-else
          class="inline-flex min-w-[140px] items-center justify-center border border-success-border bg-success-surface px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.1em] text-success"
          style="font-family: var(--font-mono)"
        >
          Completed
        </span>
      </div>
    </div>
  </div>
</template>
