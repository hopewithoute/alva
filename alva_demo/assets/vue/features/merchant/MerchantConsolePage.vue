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
    count: props.new_orders_count ?? props.sales_orders?.filter(o => o.lifecycle_status === 'new').length ?? 0,
    description: "Advance the order lifecycle and inspect filters.",
  },
  {
    label: "Inventory",
    value: "inventory",
    count: props.low_stock_count ?? props.products?.filter(p => p.stock <= 25).length ?? 0,
    description: "Track low stock and update media or counts in place.",
  },
  {
    label: "Support",
    value: "support",
    count: props.waiting_conversations_count ?? props.conversations?.filter(c => c.needs_merchant_reply).length ?? 0,
    description: "Work the shopper queue without losing realtime context.",
  },
]);

const active_tab_description = computed(() => {
  const tab = merchant_tabs.value.find((t) => t.value === active_tab.value);
  return tab?.description ?? "";
});
</script>

<template>
  <div class="max-w-7xl mx-auto py-12" data-testid="merchant-console-vue">
    <!-- Header Section -->
    <section class="border-b border-[var(--color-rule)] pb-12 mb-12">
      <div class="grid grid-cols-1 xl:grid-cols-[2fr_1fr] gap-12 items-end">
        <div class="space-y-6">
          <h1 class="text-4xl lg:text-5xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display); line-height: 1.1;">
            Operate orders, inventory, and support from one queue.
          </h1>
          <p class="max-w-xl text-base text-[var(--color-ink-2)]" style="line-height: 1.6;">
            This showcase keeps the merchant side operational: new orders, low
            stock, and customer replies stay visible while filters stay on the
            same subscription-backed surface.
          </p>
        </div>

        <div class="flex gap-12 xl:justify-end border-t border-[var(--color-rule)] xl:border-t-0 pt-8 xl:pt-0">
          <div class="space-y-2">
            <p class="text-xs uppercase tracking-[0.1em] text-danger" style="font-family: var(--font-mono)">Needs Attention</p>
            <p class="text-5xl text-danger" style="font-family: var(--font-display)">{{ props.merchant_attention_count ?? 0 }}</p>
          </div>
          <div class="space-y-2">
            <p class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">In Progress</p>
            <p class="text-5xl text-[var(--color-ink)]" style="font-family: var(--font-display)">{{ props.processing_orders_count ?? 0 }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- Navigation Section -->
    <div class="border-b border-[var(--color-rule)] mb-10 flex flex-col sm:flex-row sm:items-baseline sm:justify-between gap-6">
      <nav class="-mb-px flex gap-8" aria-label="Merchant Tabs">
        <button
          v-for="tab in merchant_tabs"
          :key="tab.value"
          :data-testid="`merchant-console-tab-${tab.value}`"
          :aria-selected="active_tab === tab.value"
          @click="active_tab = tab.value"
          :class="[
            'pb-4 text-xs font-semibold tracking-[0.1em] uppercase transition-colors border-b-2 flex items-center gap-2',
            active_tab === tab.value
              ? 'border-[var(--color-ink)] text-[var(--color-ink)]'
              : 'border-transparent text-[var(--color-ink-2)] hover:text-[var(--color-ink)]'
          ]"
          style="font-family: var(--font-mono)"
        >
          <span>{{ tab.label }}</span>
          <span
            v-if="tab.count !== undefined"
            class="inline-flex h-4 min-w-[1.25rem] items-center justify-center px-1 text-[10px] font-mono font-semibold"
            :class="
              tab.count > 0
                ? (tab.value === 'orders' ? 'bg-[var(--color-ink)] text-[var(--color-paper)]' : 'bg-[var(--color-danger)] text-white')
                : 'bg-[var(--color-rule-2)] text-[var(--color-ink)]'
            "
          >
            {{ tab.count }}
          </span>
        </button>
      </nav>
      <p class="pb-4 text-sm text-[var(--color-ink-2)] italic" style="font-family: var(--font-display);">{{ active_tab_description }}</p>
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
