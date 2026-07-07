<script setup lang="ts">
import { reactive, watch, computed } from "vue";
import { usePageEvent, usePageState } from "alva";
import type { MerchantConsoleLiveEvents } from "../../../js/alva/MerchantConsoleLive.events";
import type { Product } from "../../../js/alva/types";
import MerchantInventoryItem from "./MerchantInventoryItem.vue";
import Button from "../../shared/ui/button/Button.vue";
import { useDebounce } from "../../utils/debounce";

const { products, is_inventory_filtered, route_filters } = usePageState<{
  products?: Product[];
  is_inventory_filtered?: boolean;
  route_filters?: {
    inv_query?: string;
    inv_low_stock?: boolean;
  };
}>();

const inventory_filters = reactive({
  query: route_filters?.value?.inv_query || "",
  low_stock_only: route_filters?.value?.inv_low_stock || false,
});

const filterInventoryEvent = usePageEvent<MerchantConsoleLiveEvents, "console.filter_inventory">("console.filter_inventory");

watch(
  inventory_filters,
  useDebounce((filters: any) => {
    filterInventoryEvent.call({
      query: filters.query,
      low_stock_only: filters.low_stock_only,
    });
  }, 300),
  { deep: true },
);

const clearInventoryFilters = () => {
  inventory_filters.query = "";
  inventory_filters.low_stock_only = false;
};

const visible_products = computed(() => {
  let list = products?.value || [];
  if (inventory_filters.low_stock_only) {
    list = list.filter(p => p.stock_quantity <= 25);
  }
  if (inventory_filters.query) {
    const q = inventory_filters.query.toLowerCase();
    list = list.filter(p => p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q));
  }
  return list;
});
</script>

<template>
  <section class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
    <div class="flex flex-col gap-4 border-b border-zinc-200 pb-5 md:flex-row md:items-center md:justify-between">
      <div class="flex items-center gap-3">
        <h2 class="text-lg font-semibold text-zinc-900">Inventory</h2>
        <span class="inline-flex items-center rounded-full bg-zinc-100 px-2.5 py-1 text-zinc-700">
          {{ visible_products.length }} products
        </span>
      </div>

      <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
        <label class="flex min-w-[200px] flex-col gap-2 text-sm font-medium text-zinc-700">
          <input
            v-model="inventory_filters.query"
            data-testid="merchant-inventory-query"
            type="text"
            placeholder="Search by SKU or name"
            class="h-9 rounded-md border border-zinc-300 px-3 text-sm font-normal text-zinc-950"
          />
        </label>

        <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
          <label class="inline-flex items-center gap-2 text-sm font-medium text-zinc-700">
            <input
              v-model="inventory_filters.low_stock_only"
              type="checkbox"
              class="h-4 w-4 rounded border-zinc-300"
            />
            Low stock only
          </label>
          <Button variant="secondary" size="sm" :disabled="!is_inventory_filtered?.value" @click="clearInventoryFilters">
            Reset
          </Button>
        </div>
      </div>
    </div>

    <div v-if="visible_products.length === 0" class="py-12 text-center text-sm text-zinc-500">
      No products match your current filters.
    </div>
    <div v-else class="mt-6 grid grid-cols-1 gap-4 xl:grid-cols-2">
      <MerchantInventoryItem v-for="product in visible_products" :key="product.id" :product="product" />
    </div>
  </section>
</template>
