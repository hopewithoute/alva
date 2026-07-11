<script setup lang="ts">
import { reactive, watch } from "vue";
import type { Order } from "../../../js/alva/types";
import type { OrderFilters } from "../merchant/types";
import MerchantOrderItem from "./MerchantOrderItem.vue";
import Button from "../../shared/ui/button/Button.vue";
import { Select, SelectContent, SelectGroup, SelectItem, SelectTrigger, SelectValue } from "@/vue/components/ui/select";
import { useDebounce } from "../../utils/debounce";
import { useRouteQueryPatch } from "../../shared/useRouteQueryPatch";

const props = defineProps<{
  salesOrders?: Order[];
  isOrderFiltered?: boolean;
  initialFilters?: OrderFilters;
}>();

const { patchQuery } = useRouteQueryPatch();

const order_filters = reactive<OrderFilters>({
  status: props.initialFilters?.status || "all",
  customer: props.initialFilters?.customer || "",
  product: props.initialFilters?.product || "",
});

watch(
  () => props.initialFilters,
  (newVal) => {
    if (!newVal) return;
    order_filters.status = newVal.status || "all";
    order_filters.customer = newVal.customer || "";
    order_filters.product = newVal.product || "";
  },
  { deep: true, immediate: true }
);

watch(
  order_filters,
  useDebounce((filters: OrderFilters) => {
    patchQuery({
      order_status: filters.status === "all" ? null : filters.status,
      order_customer: filters.customer || null,
      order_product: filters.product || null,
    });
  }, 300),
  { deep: true },
);

const clearOrderFilters = () => {
  order_filters.status = "all";
  order_filters.customer = "";
  order_filters.product = "";
};

const order_status_options: Array<{ label: string; value: Order["lifecycle_status"] | "all" }> = [
  { label: "All", value: "all" },
  { label: "New", value: "new" },
  { label: "Processing", value: "processing" },
  { label: "Fulfilled", value: "fulfilled" },
];
</script>

<template>
  <section class="rounded-xl border border-[var(--color-rule)] bg-[var(--color-paper)] p-6 shadow-sm">
    <div class="flex flex-col gap-4 border-b border-[var(--color-rule)] pb-5 md:flex-row md:items-center md:justify-between">
      <div class="flex items-center gap-3">
        <h2 class="text-lg font-semibold text-[var(--color-ink)]" style="font-family: var(--font-display);">Orders</h2>
        <span class="inline-flex items-center rounded-full bg-[var(--color-rule)] px-2.5 py-1 text-[var(--color-ink-2)]">
          {{ salesOrders?.length || 0 }} orders
        </span>
      </div>

      <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
        <label class="flex items-center gap-2 text-sm font-medium text-[var(--color-ink-2)]">
          <span>Status</span>
          <Select v-model="order_filters.status">
            <SelectTrigger class="w-[140px] h-9 bg-transparent border-[var(--color-rule)] text-[var(--color-ink)]">
              <SelectValue placeholder="Status" />
            </SelectTrigger>
            <SelectContent>
              <SelectGroup>
                <SelectItem v-for="opt in order_status_options" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </SelectItem>
              </SelectGroup>
            </SelectContent>
          </Select>
        </label>
        <div class="h-6 w-px bg-zinc-200 hidden sm:block"></div>
        <input
          v-model="order_filters.customer"
          data-testid="merchant-order-customer-query"
          type="text"
          placeholder="Filter by customer"
          class="h-9 w-40 rounded-md border border-[var(--color-rule)] px-3 text-sm font-normal text-[var(--color-ink)] bg-transparent"
        />
        <input
          v-model="order_filters.product"
          type="text"
          placeholder="Filter by product"
          class="h-9 w-40 rounded-md border border-[var(--color-rule)] px-3 text-sm font-normal text-[var(--color-ink)] bg-transparent"
        />
        <Button variant="secondary" size="sm" :disabled="!isOrderFiltered" @click="clearOrderFilters">
          Reset
        </Button>
      </div>
    </div>

    <div v-if="!salesOrders?.length" class="py-12 text-center text-sm text-[var(--color-ink-2)]">
      No orders match your current filters.
    </div>
    <div v-else class="mt-6 grid grid-cols-1 gap-4 xl:grid-cols-2">
      <MerchantOrderItem v-for="order in salesOrders || []" :key="order.id" :order="order" />
    </div>
  </section>
</template>
