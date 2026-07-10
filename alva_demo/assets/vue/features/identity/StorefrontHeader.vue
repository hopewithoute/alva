<script setup lang="ts">
import { ref, watch } from "vue";
import { useAlva } from "../../../js/alva";
import { useDebounce } from "../../utils/debounce";
import { useRouteQueryPatch } from "../../shared/useRouteQueryPatch";

const alva = useAlva();

const props = defineProps<{
  recentOrderCount: number;
  recentOrderItems: number;
  connectedCustomerName?: string | null;
}>();

const emit = defineEmits<{
  (e: "open-orders"): void;
}>();

const { patchQuery } = useRouteQueryPatch();
const customerName = ref(props.connectedCustomerName || "");
let latestIdentityRequest = 0;

watch(() => props.connectedCustomerName, (newName) => {
  const nextName = newName || "";

  if (nextName !== customerName.value) {
    customerName.value = nextName;
  }
});

const handleIdentityChange = useDebounce(async (newName: string) => {
  const trimmed = newName.trim();

  if (trimmed === (props.connectedCustomerName || "")) {
    return;
  }

  if (trimmed === "") {
    latestIdentityRequest += 1;

    patchQuery({
      customer_name: null,
      conversation_id: null
    });

    return;
  }

  const requestId = ++latestIdentityRequest;
  const result = await alva.support.get_conversation({
    customer_name: trimmed
  });

  if (requestId !== latestIdentityRequest) {
    return;
  }

  if (result.ok) {
    patchQuery({
      customer_name: trimmed,
      conversation_id: result.data?.id || null
    });
    return;
  }

  if (result.error?.type === "not_found") {
    patchQuery({
      customer_name: trimmed,
      conversation_id: null
    });
  }
}, 500);

watch(customerName, (newName) => {
  void handleIdentityChange(newName);
});
</script>

<template>
  <div class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
    <div class="space-y-6">
      <div class="space-y-2">
        <p class="text-sm font-medium text-zinc-500">
          Customer Storefront surface
        </p>
        <h1 class="text-2xl font-semibold text-zinc-950">
          Browse the catalog and keep your support thread close.
        </h1>
        <p class="max-w-2xl text-sm text-zinc-500">
          Enter your customer name once to place orders, track status from
          Recent Orders, and keep chatting with merchant support in the side
          panel.
        </p>
      </div>

      <div class="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between">
        <label class="flex min-w-[240px] flex-col gap-2 text-sm font-medium text-zinc-700">
          <span>Your Name</span>
          <input
            id="customerName"
            v-model="customerName"
            type="text"
            placeholder="e.g. Alice"
            class="h-11 rounded-md border border-zinc-300 px-3 text-sm font-normal text-zinc-950"
          />
        </label>

        <div class="flex flex-col gap-2 sm:flex-row sm:items-end">
          <button
            type="button"
            class="inline-flex h-11 min-w-[190px] items-center justify-between rounded-md border border-zinc-300 bg-white px-4 text-left transition-colors hover:bg-zinc-50 disabled:cursor-not-allowed disabled:border-zinc-200 disabled:bg-zinc-100"
            :disabled="recentOrderCount === 0"
            @click="emit('open-orders')"
          >
            <span class="space-y-0.5">
              <span class="block text-[11px] font-medium uppercase tracking-wide text-zinc-500">Recent Orders</span>
              <span class="block text-sm font-medium text-zinc-950">
                {{ recentOrderCount === 0 ? "No orders yet" : `${recentOrderCount} orders` }}
              </span>
            </span>
            <span class="inline-flex min-w-[2rem] items-center justify-center rounded-full bg-zinc-950 px-2 py-1 text-xs font-semibold text-white">
              {{ recentOrderItems }}
            </span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
