<script setup lang="ts">
import { computed, ref } from "vue";
import { useAlvaApi } from "../../../js/alva/composables/useAlvaApi";
import type { Order } from "../../../js/alva/types";
import OrderStatusBadge from "../../shared/ui/badge/OrderStatusBadge.vue";
import Button from "../../shared/ui/button/Button.vue";

const props = defineProps<{
  order: Order;
}>();

const api = useAlvaApi();
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

      const result = await api.call["sales.begin_processing"]({ id: props.order.id });

      if (!result.ok) {
        operationError.value = result.error?.message || "Failed to begin processing order.";
      }
    } else if (props.order.lifecycle_status === "processing") {
      pendingAction.value = "fulfill";

      const result = await api.call["sales.fulfill"]({ id: props.order.id });

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
    class="flex flex-col gap-4 rounded-lg border border-zinc-200 p-4 transition-colors hover:bg-zinc-50 lg:flex-row lg:items-center lg:justify-between"
  >
    <div class="min-w-0">
      <div class="flex flex-wrap items-center gap-2">
        <p class="font-medium text-zinc-900">
          Order by
          <span class="font-semibold">{{ order.customer_name }}</span>
        </p>
        <span
          v-if="order.lifecycle_status === 'new'"
          class="inline-flex items-center rounded-full bg-red-100 px-2.5 py-1 text-[11px] font-medium uppercase tracking-wide text-red-700"
        >
          New
        </span>
      </div>
      <p class="mt-1 text-sm text-zinc-500">
        {{ getOrderProductName() }} (Qty: {{ order.quantity }})
      </p>
      <p class="mt-2 text-xs text-zinc-400">
        {{ formatDateTime(order.created_at) }}
      </p>
      <p v-if="operationError" class="mt-2 text-xs text-red-600">
        {{ operationError }}
      </p>
    </div>

    <div class="flex flex-wrap items-center gap-3 lg:justify-end">
      <OrderStatusBadge :status="order.lifecycle_status" />

      <div class="flex min-w-[136px] justify-end">
        <Button
          v-if="hasOrderAction"
          variant="secondary"
          size="sm"
          class="min-w-[136px]"
          @click="runOrderAction"
          :disabled="isLoading"
        >
          {{ orderActionLabel }}
        </Button>
        <span
          v-else
          class="inline-flex min-w-[136px] items-center justify-center rounded-md border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-xs font-medium text-emerald-700"
        >
          Completed
        </span>
      </div>
    </div>
  </div>
</template>
