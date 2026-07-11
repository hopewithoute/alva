<script setup lang="ts">
import { reactive, watch } from "vue";
import type { Product } from "../../../js/alva/types";
import MerchantInventoryItem from "./MerchantInventoryItem.vue";
import type { InventoryFilters } from "../merchant/types";
import Button from "../../shared/ui/button/Button.vue";
import { useDebounce } from "../../utils/debounce";
import { useRouteQueryPatch } from "../../shared/useRouteQueryPatch";

const props = defineProps<{
  products?: Product[];
  isInventoryFiltered?: boolean;
  initialFilters?: InventoryFilters;
}>();

const { patchQuery } = useRouteQueryPatch();

const inventory_filters = reactive<InventoryFilters>({
  query: props.initialFilters?.query || "",
  low_stock: props.initialFilters?.low_stock || false,
});

watch(
  () => props.initialFilters,
  (newVal) => {
    if (!newVal) return;
    inventory_filters.query = newVal.query || "";
    inventory_filters.low_stock = newVal.low_stock || false;
  },
  { deep: true, immediate: true }
);

watch(
  inventory_filters,
  useDebounce((filters: InventoryFilters) => {
    patchQuery({
      inv_query: filters.query || null,
      inv_low_stock: filters.low_stock ? "true" : null,
    });
  }, 300),
  { deep: true },
);

const clearInventoryFilters = () => {
  inventory_filters.query = "";
  inventory_filters.low_stock = false;
};

</script>

<template>
  <section class="rounded-xl border border-[var(--color-rule)] bg-[var(--color-paper)] p-6 shadow-sm">
    <div class="flex flex-col gap-4 border-b border-[var(--color-rule)] pb-5 md:flex-row md:items-center md:justify-between">
      <div class="flex items-center gap-3">
        <h2 class="text-lg font-semibold text-[var(--color-ink)]" style="font-family: var(--font-display);">Inventory</h2>
        <span class="inline-flex items-center rounded-full bg-[var(--color-rule)] px-2.5 py-1 text-[var(--color-ink-2)]">
          {{ props.products?.length || 0 }} products
        </span>
      </div>

      <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
        <label class="flex min-w-[200px] flex-col gap-2 text-sm font-medium text-[var(--color-ink-2)]">
          <input
            v-model="inventory_filters.query"
            data-testid="merchant-inventory-query"
            type="text"
            placeholder="Search by name or description"
            class="h-9 rounded-md border border-[var(--color-rule)] px-3 text-sm font-normal text-[var(--color-ink)]"
          />
        </label>

        <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
          <label class="flex items-center gap-2 text-sm font-medium text-[var(--color-ink-2)]">
          <input v-model="inventory_filters.low_stock" type="checkbox" class="h-4 w-4 rounded border-[var(--color-rule)]" />
          Low stock only
        </label>
        <div class="h-6 w-px bg-zinc-200 hidden sm:block"></div>
          <Button variant="secondary" size="sm" :disabled="!isInventoryFiltered" @click="clearInventoryFilters">
            Reset
          </Button>
        </div>
      </div>
    </div>

    <div v-if="!props.products?.length" class="py-12 text-center text-sm text-[var(--color-ink-2)]">
      No products match your current filters.
    </div>
    <div v-else class="mt-6 grid grid-cols-1 gap-4 xl:grid-cols-2">
      <MerchantInventoryItem v-for="product in props.products || []" :key="product.id" :product="product" />
    </div>
  </section>
</template>
