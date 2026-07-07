<script setup lang="ts">
import { ref, computed } from "vue";
import { providePageState } from "../../../../js/alva/usePageState";
import type { Order, Product, Conversation, SupportMessage } from "../../../js/alva/types";
import MerchantOrdersTab from "../sales/MerchantOrdersTab.vue";
import MerchantInventoryTab from "../catalog/MerchantInventoryTab.vue";
import MerchantSupportTab from "../support/MerchantSupportTab.vue";

import type { OrderFilters, InventoryFilters, ConversationFilters } from "./types";

type MerchantConsoleTab = "orders" | "inventory" | "support";

const props = defineProps<{
  sales_orders?: Order[];
  products?: Product[];
  conversations?: Conversation[];
  active_conversation_id?: string | null;
  support_messages?: SupportMessage[];
  new_orders_count?: number;
  processing_orders_count?: number;
  waiting_conversations_count?: number;
  merchant_attention_count?: number;
  is_order_filtered?: boolean;
  is_inventory_filtered?: boolean;
  is_conversation_filtered?: boolean;
  low_stock_count?: number;
  order_filters?: OrderFilters;
  inventory_filters?: InventoryFilters;
  conversation_filters?: ConversationFilters;
}>();

providePageState(props);

const active_tab = ref<MerchantConsoleTab>("orders");

const merchant_tabs = computed<
  Array<{
    label: string;
    value: MerchantConsoleTab;
    count: number;
    description: string;
  }>
>(() => [
  {
    label: "Orders",
    value: "orders",
    count: props.new_orders_count ?? 0,
    description: "Advance the order lifecycle and inspect filters.",
  },
  {
    label: "Inventory",
    value: "inventory",
    count: props.low_stock_count ?? 0,
    description: "Track low stock and update media or counts in place.",
  },
  {
    label: "Support",
    value: "support",
    count: props.waiting_conversations_count ?? 0,
    description: "Work the shopper queue without losing realtime context.",
  },
]);

const active_tab_description = computed(() => {
  const tab = merchant_tabs.value.find((t) => t.value === active_tab.value);
  return tab?.description ?? "";
});
</script>

<template>
  <div class="space-y-6" data-testid="merchant-console-vue">
    <section class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
      <div class="flex flex-col gap-6 xl:flex-row xl:items-start xl:justify-between">
        <div class="space-y-2">
          <p class="text-sm font-medium text-zinc-500">Merchant Console surface</p>
          <h1 class="text-2xl font-semibold text-zinc-950">
            Operate orders, inventory, and support from one queue.
          </h1>
          <p class="max-w-3xl text-sm text-zinc-500">
            This showcase keeps the merchant side operational: new orders, low stock, and customer replies stay visible while filters stay on the same collection-backed surface.
          </p>
        </div>

        <div class="grid gap-3 sm:grid-cols-2 xl:min-w-[420px] xl:grid-cols-2">
          <div class="rounded-lg border border-red-200 bg-red-50 p-4">
            <p class="text-xs font-medium uppercase tracking-wide text-red-600">Needs Attention</p>
            <div class="mt-2 flex items-end justify-between gap-3">
              <span class="text-3xl font-semibold text-red-700">{{ props.merchant_attention_count ?? 0 }}</span>
              <span class="text-sm text-red-600">Total items</span>
            </div>
          </div>

          <div class="rounded-lg border border-zinc-200 bg-zinc-50 p-4">
            <p class="text-xs font-medium uppercase tracking-wide text-zinc-500">In Progress</p>
            <div class="mt-2 flex items-end justify-between gap-3">
              <span class="text-3xl font-semibold text-zinc-900">{{ props.processing_orders_count ?? 0 }}</span>
              <span class="text-sm text-zinc-500">Processing</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <nav class="flex gap-2 rounded-lg border border-zinc-200 bg-white p-1 shadow-sm sm:w-auto" aria-label="Merchant Tabs">
        <button
          v-for="tab in merchant_tabs"
          :key="tab.value"
          :data-testid="`merchant-console-tab-${tab.value}`"
          :aria-selected="active_tab === tab.value"
          @click="active_tab = tab.value"
          :class="[
            'relative rounded-md px-4 py-2 text-sm font-medium transition-colors',
            active_tab === tab.value
              ? 'bg-zinc-100 text-zinc-950 shadow-sm'
              : 'text-zinc-600 hover:bg-zinc-50 hover:text-zinc-900'
          ]"
        >
          {{ tab.label }}
          <span
            v-if="tab.count > 0"
            class="ml-2 inline-flex h-5 items-center justify-center rounded-full px-2 text-[11px] font-medium"
            :class="tab.value === 'orders' ? 'bg-zinc-950 text-white' : 'bg-red-100 text-red-700'"
          >
            {{ tab.count }}
          </span>
        </button>
      </nav>
      <p class="text-sm text-zinc-500">{{ active_tab_description }}</p>
    </div>

    <!-- Features Content -->
    <MerchantOrdersTab
      v-if="active_tab === 'orders'"
      data-testid="merchant-console-panel-orders"
    />

    <MerchantInventoryTab
      v-else-if="active_tab === 'inventory'"
      data-testid="merchant-console-panel-inventory"
    />

    <MerchantSupportTab
      v-else-if="active_tab === 'support'"
      data-testid="merchant-console-panel-support"
    />

  </div>
</template>
