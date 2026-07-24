<script setup lang="ts">
import { ref, watch } from "vue";
import { watchDebounced } from "@vueuse/core";
import { useAlva } from "@/js/alva";
import { useRouteQueryPatch } from "@/vue/shared/useRouteQueryPatch";

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

watch(
  () => props.connectedCustomerName,
  (newName) => {
    const nextName = newName || "";

    if (nextName !== customerName.value) {
      customerName.value = nextName;
    }
  }
);

watchDebounced(
  customerName,
  async (newName) => {
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
  },
  { debounce: 500 }
);
</script>

<template>
  <div class="border-b border-[var(--color-rule)] pb-12">
    <div class="space-y-8">
      <div class="max-w-3xl space-y-4">
        <h1
          class="text-4xl font-normal text-[var(--color-ink)] lg:text-5xl"
          style="font-family: var(--font-display); line-height: 1.1"
        >
          Browse the catalog and keep your support thread close.
        </h1>
        <p class="text-base text-[var(--color-ink-2)]" style="line-height: 1.6">
          Enter your customer name once to place orders, track status from Recent Orders, and keep
          chatting with merchant support in the side panel.
        </p>
      </div>

      <div
        class="flex flex-col gap-6 border-t border-[var(--color-rule)] pt-4 lg:flex-row lg:items-end lg:justify-between"
      >
        <label
          class="flex min-w-[280px] flex-col gap-2 text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)]"
          style="font-family: var(--font-mono)"
        >
          <span>Your Name</span>
          <input
            id="customerName"
            v-model="customerName"
            type="text"
            placeholder="e.g. Alice"
            class="h-10 rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 text-sm font-normal text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0"
          />
        </label>

        <div class="flex flex-col gap-2 sm:flex-row sm:items-end">
          <button
            type="button"
            class="group inline-flex h-11 min-w-[220px] items-center justify-between rounded-none border border-[var(--color-ink)] bg-transparent px-4 text-left transition-colors hover:bg-[var(--color-ink)] hover:text-[var(--color-paper)] disabled:cursor-not-allowed disabled:border-[var(--color-rule)] disabled:opacity-50"
            :disabled="recentOrderCount === 0"
            @click="emit('open-orders')"
          >
            <span class="space-y-0.5">
              <span
                class="block text-[10px] font-semibold uppercase tracking-[0.1em] text-[var(--color-ink-2)] transition-colors group-hover:text-[var(--color-paper)]"
                style="font-family: var(--font-mono)"
                >Recent Orders</span
              >
              <span class="block text-xs font-medium uppercase tracking-[0.05em]">
                {{ recentOrderCount === 0 ? "No orders yet" : `${recentOrderCount} orders` }}
              </span>
            </span>
            <span
              class="inline-flex min-w-[1.5rem] items-center justify-center rounded-none bg-[var(--color-ink)] px-2 py-0.5 font-mono text-xs text-[var(--color-paper)] transition-colors group-hover:bg-[var(--color-paper)] group-hover:text-[var(--color-ink)]"
            >
              {{ recentOrderItems }}
            </span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
