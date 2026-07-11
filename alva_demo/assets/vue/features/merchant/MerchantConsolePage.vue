<script setup lang="ts">
import { ref, computed } from "vue";
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
    <section class="rounded-xl border border-[var(--color-rule)] bg-[var(--color-paper)] p-6 shadow-sm">
      <div class="flex flex-col gap-6 xl:flex-row xl:items-start xl:justify-between">
        <div class="space-y-2">
          <p class="text-sm font-medium text-[var(--color-ink-2)]">Merchant Console surface</p>
          <h1 class="text-2xl font-semibold text-[var(--color-ink)]" style="font-family: var(--font-display);">
            Operate orders, inventory, and support from one queue.
          </h1>
          <p class="max-w-3xl text-sm text-[var(--color-ink-2)]">
            This showcase keeps the merchant side operational: new orders, low
            stock, and customer replies stay visible while filters stay on the
            same subscription-backed surface.
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

          <div class="rounded-lg border border-[var(--color-rule)] bg-[var(--color-rule)] p-4">
            <p class="text-xs font-medium uppercase tracking-wide text-[var(--color-ink-2)]">In Progress</p>
            <div class="mt-2 flex items-end justify-between gap-3">
              <span class="text-3xl font-semibold text-[var(--color-ink)]">{{ props.processing_orders_count ?? 0 }}</span>
              <span class="text-sm text-[var(--color-ink-2)]">Processing</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <nav class="flex gap-2 rounded-lg border border-[var(--color-rule)] bg-[var(--color-paper)] p-1 shadow-sm sm:w-auto" aria-label="Merchant Tabs">
        <button
          v-for="tab in merchant_tabs"
          :key="tab.value"
          :data-testid="`merchant-console-tab-${tab.value}`"
          :aria-selected="active_tab === tab.value"
          @click="active_tab = tab.value"
          :class="[
            'relative rounded-md px-4 py-2 text-sm font-medium transition-colors',
            active_tab === tab.value
              ? 'bg-[var(--color-rule)] text-[var(--color-ink)] shadow-sm'
              : 'text-[var(--color-ink-2)] hover:bg-[var(--color-rule)] hover:text-[var(--color-ink)]'
          ]"
        >
          {{ tab.label }}
          <span
            v-if="tab.count > 0"
            class="ml-2 inline-flex h-5 items-center justify-center rounded-full px-2 text-[11px] font-medium"
            :class="tab.value === 'orders' ? 'bg-[var(--color-ink)] text-[var(--color-paper)]' : 'bg-red-100 text-red-700'"
          >
            {{ tab.count }}
          </span>
        </button>
      </nav>
      <p class="text-sm text-[var(--color-ink-2)]">{{ active_tab_description }}</p>
    </div>

    <!-- Features Content -->
    <MerchantOrdersTab
      v-show="active_tab === 'orders'"
      :sales-orders="props.sales_orders || []"
      :is-order-filtered="props.is_order_filtered ?? false"
      :initial-filters="props.order_filters"
      data-testid="merchant-console-panel-orders"
    />

    <MerchantInventoryTab
      v-show="active_tab === 'inventory'"
      :products="props.products || []"
      :is-inventory-filtered="props.is_inventory_filtered ?? false"
      :initial-filters="props.inventory_filters"
      data-testid="merchant-console-panel-inventory"
    />

    <MerchantSupportTab
      v-show="active_tab === 'support'"
      :conversations="props.conversations || []"
      :active-conversation-id="props.active_conversation_id"
      :support-messages="props.support_messages || []"
      :is-conversation-filtered="props.is_conversation_filtered ?? false"
      :initial-filters="props.conversation_filters"
      data-testid="merchant-console-panel-support"
    />

  </div>
</template>
