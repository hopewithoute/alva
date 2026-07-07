<script setup lang="ts">
import { computed } from "vue";
import { usePageEvent } from "alva";
import type { AlvaEvents } from "../../js/alva/events";
import type { Order } from "../../js/alva/types";
import { getStatusColor } from "../../shared/utils/ui";
import Button from "../../shared/ui/button/Button.vue";

const props = defineProps<{
  order: Order;
}>();

const beginProcessingEvent = usePageEvent<AlvaEvents, "sales.begin_processing">("sales.begin_processing");
const fulfillEvent = usePageEvent<AlvaEvents, "sales.fulfill">("sales.fulfill");

const isLoading = computed(() => beginProcessingEvent.isLoading.value || fulfillEvent.isLoading.value);

const orderActionLabel = computed(() => {
  if (beginProcessingEvent.isLoading.value) return "Processing...";
  if (fulfillEvent.isLoading.value) return "Fulfilling...";
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

  if (props.order.lifecycle_status === "new") {
    await beginProcessingEvent.call({ id: props.order.id });
  } else if (props.order.lifecycle_status === "processing") {
    await fulfillEvent.call({ id: props.order.id });
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

const operationError = computed(() => {
  if (beginProcessingEvent.error.value) return beginProcessingEvent.error.value.message;
  if (fulfillEvent.error.value) return fulfillEvent.error.value.message;
  return null;
});
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
      <div
        :class="[
          'rounded-full border px-3 py-1 text-sm font-medium capitalize',
          getStatusColor(order.lifecycle_status),
        ]"
      >
        {{ order.lifecycle_status }}
      </div>

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
