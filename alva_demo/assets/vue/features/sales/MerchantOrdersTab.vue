<script setup lang="ts">
import type { Order } from "@/js/alva/types";
import {
  ORDER_STATUS,
  ORDER_FILTER_ALL,
  type OrderFilters
} from "@/vue/features/merchant/types";
import MerchantOrderItem from "./MerchantOrderItem.vue";
import Button from "@/vue/shared/ui/button/Button.vue";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue
} from "@/vue/components/ui/select";
import { useFilterQuerySync } from "@/vue/shared/useFilterQuerySync";

const props = defineProps<{
  salesOrders?: Order[];
  isOrderFiltered?: boolean;
  initialFilters?: OrderFilters;
}>();

const { filters: order_filters, resetFilters: clearOrderFilters } =
  useFilterQuerySync<OrderFilters>(
    () => props.initialFilters,
    { status: ORDER_FILTER_ALL, customer: "", product: "" },
    (filters) => ({
      order_status: filters.status === ORDER_FILTER_ALL ? null : filters.status,
      order_customer: filters.customer || null,
      order_product: filters.product || null
    })
  );

const order_status_options: Array<{ label: string; value: Order["lifecycle_status"] | typeof ORDER_FILTER_ALL }> = [
  { label: "All", value: ORDER_FILTER_ALL },
  { label: "New", value: ORDER_STATUS.NEW },
  { label: "Processing", value: ORDER_STATUS.PROCESSING },
  { label: "Fulfilled", value: ORDER_STATUS.FULFILLED }
];
</script>

<template>
  <section class="space-y-8">
    <div
      class="flex flex-col gap-6 border-b border-[var(--color-rule)] pb-6 md:flex-row md:items-end md:justify-between"
    >
      <div class="flex items-baseline gap-4">
        <h2
          class="text-2xl font-normal text-[var(--color-ink)]"
          style="font-family: var(--font-display)"
        >
          Orders
        </h2>
        <span class="text-xs text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          {{ salesOrders?.length || 0 }} total
        </span>
      </div>

      <div class="flex flex-col gap-4 sm:flex-row sm:items-end">
        <label
          class="flex flex-col gap-1 text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          <span>Status</span>
          <Select v-model="order_filters.status">
            <SelectTrigger
              class="h-8 w-[140px] rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:ring-0"
            >
              <SelectValue placeholder="Status" />
            </SelectTrigger>
            <SelectContent
              class="rounded-none border border-[var(--color-rule)] bg-[var(--color-paper)]"
            >
              <SelectGroup>
                <SelectItem v-for="opt in order_status_options" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </SelectItem>
              </SelectGroup>
            </SelectContent>
          </Select>
        </label>

        <input
          v-model="order_filters.customer"
          data-testid="merchant-order-customer-query"
          type="text"
          placeholder="Filter customer..."
          class="h-8 w-36 rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 text-sm font-normal text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0"
        />
        <input
          v-model="order_filters.product"
          type="text"
          placeholder="Filter product..."
          class="h-8 w-36 rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 text-sm font-normal text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0"
        />
        <Button
          variant="secondary"
          size="sm"
          class="rounded-none font-mono text-xs uppercase tracking-[0.1em]"
          :disabled="!isOrderFiltered"
          @click="clearOrderFilters"
        >
          Reset
        </Button>
      </div>
    </div>

    <div
      v-if="!salesOrders?.length"
      class="py-12 text-sm italic text-[var(--color-ink-2)]"
      style="font-family: var(--font-display)"
    >
      No orders match your current filters.
    </div>
    <div v-else class="grid grid-cols-1 gap-6 xl:grid-cols-2">
      <MerchantOrderItem v-for="order in salesOrders || []" :key="order.id" :order="order" />
    </div>
  </section>
</template>
