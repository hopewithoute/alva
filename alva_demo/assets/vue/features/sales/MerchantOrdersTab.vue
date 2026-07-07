<script setup lang="ts">
import { reactive, watch, computed } from "vue";
import { usePageEvent, usePageState } from "alva";
import type { MerchantConsoleLiveEvents } from "../../../js/alva/MerchantConsoleLive.events";
import type { Order } from "../../../js/alva/types";
import { useDebounce } from "../../utils/debounce";
import MerchantOrderItem from "./MerchantOrderItem.vue";
import Button from "../../shared/ui/button/Button.vue";

const { sales_orders, is_order_filtered, route_filters } = usePageState<{
  sales_orders?: Order[];
  is_order_filtered?: boolean;
  route_filters?: {
    order_status?: string;
    order_customer?: string;
    order_product?: string;
  };
}>();

type OrderStatusFilter = "all" | Order["lifecycle_status"];

const order_filters = reactive<{
  status: OrderStatusFilter;
  customer_query: string;
  product_query: string;
}>({
  status: (route_filters?.value?.order_status as OrderStatusFilter) || "all",
  customer_query: route_filters?.value?.order_customer || "",
  product_query: route_filters?.value?.order_product || "",
});

const filterOrdersEvent = usePageEvent<MerchantConsoleLiveEvents, "console.filter_orders">("console.filter_orders");

watch(
  order_filters,
  useDebounce((filters: any) => {
    filterOrdersEvent.call({
      status: filters.status || undefined,
      customer_query: filters.customer_query || undefined,
      product_query: filters.product_query || undefined,
    });
  }, 300),
  { deep: true },
);

const clearOrderFilters = () => {
  order_filters.status = "all";
  order_filters.customer_query = "";
  order_filters.product_query = "";
};

const visible_orders = computed(() => {
  let list = sales_orders?.value || [];
  if (order_filters.status !== "all") {
    list = list.filter(o => o.lifecycle_status === order_filters.status);
  }
  if (order_filters.customer_query) {
    const q = order_filters.customer_query.toLowerCase();
    list = list.filter(o => o.customer_name?.toLowerCase().includes(q));
  }
  if (order_filters.product_query) {
    const q = order_filters.product_query.toLowerCase();
    list = list.filter(o => o.product?.name.toLowerCase().includes(q));
  }
  return list;
});

const order_status_options: Array<{ label: string; value: OrderStatusFilter }> = [
  { label: "All", value: "all" },
  { label: "New", value: "new" },
  { label: "Processing", value: "processing" },
  { label: "Fulfilled", value: "fulfilled" },
];
</script>

<template>
  <section class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
    <div class="flex flex-col gap-4 border-b border-zinc-200 pb-5 md:flex-row md:items-center md:justify-between">
      <div class="flex items-center gap-3">
        <h2 class="text-lg font-semibold text-zinc-900">Orders</h2>
        <span class="inline-flex items-center rounded-full bg-zinc-100 px-2.5 py-1 text-zinc-700">
          {{ visible_orders.length }} orders
        </span>
      </div>

      <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
        <label class="flex items-center gap-2 text-sm font-medium text-zinc-700">
          <span>Status</span>
          <select
            v-model="order_filters.status"
            class="h-9 rounded-md border border-zinc-300 px-3 py-1.5 text-sm font-normal text-zinc-950"
          >
            <option v-for="opt in order_status_options" :key="opt.value" :value="opt.value">
              {{ opt.label }}
            </option>
          </select>
        </label>
        <div class="h-6 w-px bg-zinc-200 hidden sm:block"></div>
        <input
          v-model="order_filters.customer_query"
          data-testid="merchant-order-customer-query"
          type="text"
          placeholder="Filter by customer"
          class="h-9 w-40 rounded-md border border-zinc-300 px-3 text-sm font-normal text-zinc-950"
        />
        <input
          v-model="order_filters.product_query"
          type="text"
          placeholder="Filter by product"
          class="h-9 w-40 rounded-md border border-zinc-300 px-3 text-sm font-normal text-zinc-950"
        />
        <Button variant="secondary" size="sm" :disabled="!is_order_filtered?.value" @click="clearOrderFilters">
          Reset
        </Button>
      </div>
    <div v-if="visible_orders.length === 0" class="mt-6 py-12 text-center text-sm text-zinc-500">
      No orders match your current filters.
    </div>
    <div v-else class="mt-6 grid grid-cols-1 gap-4 xl:grid-cols-2">
      <MerchantOrderItem v-for="order in visible_orders" :key="order.id" :order="order" />
    </div>
  </section>
</template>
