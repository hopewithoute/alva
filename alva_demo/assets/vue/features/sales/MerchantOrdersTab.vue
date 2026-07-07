<script setup lang="ts">
import { reactive, watch, computed } from "vue";
import { usePageEvent } from "alva";
import type { MerchantConsoleLiveEvents } from "../../../js/alva/MerchantConsoleLive.events";
import type { Order } from "../../../js/alva/types";
import MerchantOrderItem from "./MerchantOrderItem.vue";
import Button from "../../shared/ui/button/Button.vue";

const props = defineProps<{
  sales_orders: Order[];
  is_filtered: boolean;
  route_filters?: any;
}>();

type OrderStatusFilter = "all" | Order["lifecycle_status"];

const order_filters = reactive<{
  status: OrderStatusFilter;
  customer_query: string;
  product_query: string;
}>({
  status: (props.route_filters?.order_status as OrderStatusFilter) || "all",
  customer_query: props.route_filters?.order_customer || "",
  product_query: props.route_filters?.order_product || "",
});

const filterOrdersEvent = usePageEvent<MerchantConsoleLiveEvents, "console.filter_orders">("console.filter_orders");

let timeoutId: any = null;
const debounce = (fn: Function, ms = 300) => {
  return (...args: any[]) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn(...args), ms);
  };
};

watch(
  order_filters,
  debounce((filters: any) => {
    filterOrdersEvent.call({
      status: filters.status,
      customer_query: filters.customer_query,
      product_query: filters.product_query,
    });
  }),
  { deep: true },
);

const clearOrderFilters = () => {
  order_filters.status = "all";
  order_filters.customer_query = "";
  order_filters.product_query = "";
};

const visible_orders = computed(() => {
  let list = props.sales_orders || [];
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
        <Button variant="secondary" size="sm" :disabled="!props.is_filtered" @click="clearOrderFilters">
          Reset
        </Button>
      </div>
    </div>

    <div v-if="visible_orders.length === 0" class="py-12 text-center text-sm text-zinc-500">
      No orders match your current filters.
    </div>
    <div v-else class="mt-6 grid grid-cols-1 gap-4 xl:grid-cols-2">
      <MerchantOrderItem v-for="order in visible_orders" :key="order.id" :order="order" />
    </div>
  </section>
</template>
