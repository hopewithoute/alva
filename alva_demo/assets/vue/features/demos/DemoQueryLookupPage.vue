<script setup lang="ts">
import { ref, computed, watch } from "vue";
import { useAlva } from "@/js/alva";
import type { Product } from "@/js/alva/types";
import Button from "@/vue/shared/ui/button/Button.vue";
import SpecimenSourceViewerModal from "@/vue/shared/components/SpecimenSourceViewerModal.vue";

const isSourceModalOpen = ref(false);

const props = defineProps<{
  products?: Product[];
}>();

const alva = useAlva();

// 2. Interactive Threshold & Search Filter State
const searchPattern = ref("");
const minStockThreshold = ref(-50);
const maxStockThreshold = ref(100);

const { data: filteredProducts, loading: loadingFiltered } = alva.catalog.use_list_products_query(
  () => ({
    query: searchPattern.value.trim() ? searchPattern.value.trim() : undefined,
    min_stock: minStockThreshold.value,
    max_stock: maxStockThreshold.value
  }),
  { debounceMs: 250 }
);

// Dynamic reactive products list
const availableProducts = computed<Product[]>(() => {
  if (props.products && props.products.length > 0) return props.products;
  if (filteredProducts.value && filteredProducts.value.length > 0) return filteredProducts.value;
  return [];
});

// 1. Single-Record Lookup State
const selectedProductId = ref("");

const syncDefaultSelectedProduct = (list: Product[]) => {
  if (list.length > 0 && !selectedProductId.value) {
    selectedProductId.value = list[0].id;
  }
};

watch(availableProducts, syncDefaultSelectedProduct, { immediate: true });

const {
  data: selectedProduct,
  loading: loadingSingle,
  refetch: refetchSingle
} = alva.catalog.use_get_product_by_id(selectedProductId);

// 3. Realtime Signal Auto-Refresh Query vs Fallback Polling
const isPolling = ref(false);
const signalRefreshCount = ref(0);
const lastSignalTime = ref<string | null>(null);

// Query 3A: Signal-Driven Auto-Refresh (Instant <20ms updates)
const { data: signalProducts, refetch: refetchSignalQuery } = alva.catalog.use_list_products_query(
  () => ({ query: "" }),
  { autoRefreshOnSignal: "catalog.product_updated" }
);

const previousSignalStock = ref<Record<string, number>>({});
const signalChangedIds = ref<Set<string>>(new Set());

const handleSignalProductsChange = (newList: Product[] | null) => {
  if (!newList) return;
  const changed = new Set<string>();
  for (const item of newList) {
    const prev = previousSignalStock.value[item.id];
    if (prev !== undefined && prev !== item.stock) {
      changed.add(item.id);
    }
    previousSignalStock.value[item.id] = item.stock;
  }
  if (changed.size > 0) {
    signalChangedIds.value = changed;
    setTimeout(() => {
      signalChangedIds.value = new Set();
    }, 2200);
  }
  signalRefreshCount.value++;
  lastSignalTime.value = new Date().toLocaleTimeString();
};

watch(signalProducts, handleSignalProductsChange, { immediate: true });

// Query 3B: Periodic Fallback Polling (3000ms updates)
const pollCount = ref(0);
const lastPolledTime = ref<string | null>(null);

const { data: polledProducts } = alva.catalog.use_list_products_query(() => ({ query: "" }), {
  pollIntervalMs: () => (isPolling.value ? 3000 : 0)
});

const previousPollStock = ref<Record<string, number>>({});
const pollChangedIds = ref<Set<string>>(new Set());

const handlePolledProductsChange = (newList: Product[] | null) => {
  if (!newList) return;
  if (isPolling.value) {
    const changed = new Set<string>();
    for (const item of newList) {
      const prev = previousPollStock.value[item.id];
      if (prev !== undefined && prev !== item.stock) {
        changed.add(item.id);
      }
      previousPollStock.value[item.id] = item.stock;
    }
    if (changed.size > 0) {
      pollChangedIds.value = changed;
      setTimeout(() => {
        pollChangedIds.value = new Set();
      }, 2200);
    }
    pollCount.value++;
    lastPolledTime.value = new Date().toLocaleTimeString();
  } else {
    for (const item of newList) {
      previousPollStock.value[item.id] = item.stock;
    }
  }
};

watch(polledProducts, handlePolledProductsChange, { immediate: true });

// Server Mutation Simulator
const isSimulatingMutate = ref(false);
const mutationNotice = ref<string | null>(null);

const triggerDbMutation = async () => {
  const list = availableProducts.value;
  if (list.length === 0 || isSimulatingMutate.value) return;

  isSimulatingMutate.value = true;
  mutationNotice.value = null;

  const randomProduct = list[Math.floor(Math.random() * list.length)];
  const newRandomStock = Math.floor(Math.random() * 90) + 10;

  const res = await alva.catalog.adjust_stock({ id: randomProduct.id, stock: newRandomStock });

  if (res.ok) {
    mutationNotice.value = `Updated inventory for "${randomProduct.name}" to ${newRandomStock} units via PubSub signal`;
    await refetchSignalQuery();
    if (randomProduct.id === selectedProductId.value) {
      await refetchSingle();
    }
  } else {
    mutationNotice.value = `Mutation failed: ${res.error?.message || "Unknown error"}`;
  }

  isSimulatingMutate.value = false;
};

export type DtoInspectTab = "card" | "json";

const activeTab = ref<DtoInspectTab>("card");
</script>

<template>
  <div class="w-full space-y-16 py-4" data-testid="demo-query-lookup-vue">
    <!-- Broadsheet Header -->
    <header class="space-y-6 border-b border-[var(--color-rule)] pb-12">
      <div class="space-y-1">
        <span
          class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          № 04 — QUERY ENGINE SPECIMEN
        </span>
        <p
          class="text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          Declarative Data Access Architecture
        </p>
      </div>
      <h1
        class="text-5xl font-normal text-[var(--color-ink)]"
        style="font-family: var(--font-display); line-height: 1.1"
      >
        Single-Record Lookups &amp; Reactive Query Filtering.
      </h1>
      <div class="flex flex-col justify-between gap-6 sm:flex-row sm:items-end">
        <p class="max-w-[65ch] text-lg text-[var(--color-ink-2)]" style="line-height: 1.7">
          Retrieve typed DTO entities by primary key, apply dynamic AST range filters over
          WebSockets, and compare real-time PubSub signal auto-refreshing against fallback polling.
        </p>
        <Button variant="specimen" @click="isSourceModalOpen = true">
          <span>⚡ INSPECT SPECIMEN CODE</span>
        </Button>
      </div>
    </header>

    <!-- Section 1: Single-Record Lookup -->
    <section class="space-y-6 border-t border-[var(--color-rule)] pt-8">
      <div
        class="flex flex-col justify-between gap-4 border-b border-[var(--color-rule)] pb-4 sm:flex-row sm:items-baseline"
      >
        <div class="space-y-1">
          <span
            class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            01 / RESOURCE DTO FETCHING
          </span>
          <h2
            class="text-3xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            Single-Entity Lookup (<code>use_get_product_by_id</code>)
          </h2>
        </div>

        <div class="flex items-center gap-4 font-mono text-xs">
          <button
            @click="activeTab = 'card'"
            class="border-b py-1 uppercase tracking-[0.1em] transition-colors"
            :class="
              activeTab === 'card'
                ? 'border-[var(--color-ink)] font-bold text-[var(--color-ink)]'
                : 'border-transparent text-[var(--color-ink-2)] hover:text-[var(--color-ink)]'
            "
          >
            DTO View
          </button>
          <button
            @click="activeTab = 'json'"
            class="border-b py-1 uppercase tracking-[0.1em] transition-colors"
            :class="
              activeTab === 'json'
                ? 'border-[var(--color-ink)] font-bold text-[var(--color-ink)]'
                : 'border-transparent text-[var(--color-ink-2)] hover:text-[var(--color-ink)]'
            "
          >
            Raw DTO Payload
          </button>
        </div>
      </div>

      <div class="flex flex-col gap-4 py-2 sm:flex-row sm:items-center">
        <label
          class="font-mono text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)]"
          >Select Resource ID:</label
        >
        <select
          v-model="selectedProductId"
          class="rounded-none border-0 border-b border-[var(--color-rule-2)] bg-[var(--color-paper)] px-2 py-2 font-mono text-sm text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0"
        >
          <option
            v-for="p in availableProducts"
            :key="p.id"
            :value="p.id"
            class="bg-[var(--color-paper)] text-[var(--color-ink)]"
          >
            {{ p.name }} ({{ p.id.slice(0, 8) }}...)
          </option>
        </select>
        <span
          v-if="loadingSingle"
          class="animate-pulse font-mono text-xs text-[var(--color-accent)]"
          >Fetching entity...</span
        >
      </div>

      <!-- Broadsheet DTO Card -->
      <div
        v-if="selectedProduct && activeTab === 'card'"
        class="flex flex-col items-start gap-8 border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-8 sm:flex-row"
      >
        <img
          v-if="selectedProduct.media_reference"
          :src="'/images/' + selectedProduct.media_reference"
          :alt="selectedProduct.name"
          class="h-28 w-28 flex-shrink-0 border border-[var(--color-rule-2)] bg-white object-contain p-2"
        />
        <div
          v-else
          class="flex h-28 w-28 flex-shrink-0 items-center justify-center border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] font-mono text-sm font-bold"
        >
          {{ selectedProduct.name.slice(0, 2).toUpperCase() }}
        </div>

        <div class="w-full flex-1 space-y-3 font-mono text-xs">
          <div class="flex items-baseline justify-between border-b border-[var(--color-rule)] pb-4">
            <div>
              <h3
                class="text-2xl font-normal text-[var(--color-ink)]"
                style="font-family: var(--font-display)"
              >
                {{ selectedProduct.name }}
              </h3>
              <p class="mt-1 text-[11px] text-[var(--color-ink-2)]">
                Resource Primary Key: {{ selectedProduct.id }}
              </p>
            </div>
            <span
              class="font-mono text-xs font-bold uppercase tracking-[0.1em] text-[var(--color-accent)]"
            >
              {{ selectedProduct.stock }} Units Available
            </span>
          </div>

          <p class="pt-2 font-sans text-base leading-relaxed text-[var(--color-ink-2)]">
            {{ selectedProduct.description }}
          </p>
        </div>
      </div>

      <!-- Broadsheet Raw Code Card -->
      <div
        v-else-if="selectedProduct && activeTab === 'json'"
        class="code-card overflow-x-auto p-6 text-xs leading-relaxed"
      >
        <pre class="text-emerald-400">{{ JSON.stringify(selectedProduct, null, 2) }}</pre>
      </div>
    </section>

    <!-- Section 2: Dynamic Query Filtering -->
    <section class="space-y-8 border-t border-[var(--color-rule)] pt-8">
      <div
        class="flex flex-col justify-between gap-4 border-b border-[var(--color-rule)] pb-4 sm:flex-row sm:items-baseline"
      >
        <div class="space-y-1">
          <span
            class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            02 / DYNAMIC AST QUERY FILTERING
          </span>
          <h2
            class="text-3xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            Reactive Stock Threshold Filtering
          </h2>
        </div>
        <span class="font-mono text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]">
          Matching Entities: {{ filteredProducts?.length || 0 }}
        </span>
      </div>

      <div
        class="grid grid-cols-1 gap-8 border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] p-6 sm:grid-cols-3"
      >
        <div>
          <label
            class="mb-2 block font-mono text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
            >Search Keyword:</label
          >
          <input
            v-model="searchPattern"
            placeholder="Filter by product name..."
            class="w-full rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 py-2 font-mono text-sm text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0"
          />
        </div>

        <div>
          <div
            class="mb-2 flex justify-between font-mono text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
          >
            <span>Min Inventory:</span>
            <strong class="font-bold text-[var(--color-ink)]">{{ minStockThreshold }} units</strong>
          </div>
          <input
            type="range"
            min="-50"
            max="100"
            v-model.number="minStockThreshold"
            class="w-full cursor-pointer accent-[var(--color-ink)]"
          />
        </div>

        <div>
          <div
            class="mb-2 flex justify-between font-mono text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
          >
            <span>Max Inventory:</span>
            <strong class="font-bold text-[var(--color-ink)]">{{ maxStockThreshold }} units</strong>
          </div>
          <input
            type="range"
            min="-50"
            max="100"
            v-model.number="maxStockThreshold"
            class="w-full cursor-pointer accent-[var(--color-ink)]"
          />
        </div>
      </div>

      <div
        v-if="loadingFiltered"
        class="animate-pulse py-2 font-mono text-xs text-[var(--color-accent)]"
      >
        Executing query evaluation...
      </div>

      <div
        v-else-if="filteredProducts && filteredProducts.length > 0"
        class="grid grid-cols-1 gap-6 sm:grid-cols-2 md:grid-cols-3"
      >
        <div
          v-for="item in filteredProducts"
          :key="item.id"
          class="space-y-2 border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-5 transition-colors duration-300"
          :class="{
            'border-[var(--color-ink)] bg-[var(--color-paper-2)]': signalChangedIds.has(item.id)
          }"
        >
          <div
            class="text-lg font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            {{ item.name }}
          </div>
          <div
            class="flex justify-between border-t border-[var(--color-rule)] pt-2 font-mono text-xs text-[var(--color-ink-2)]"
          >
            <span>Inventory Level:</span>
            <span class="font-bold text-[var(--color-ink)]">{{ item.stock }} units</span>
          </div>
        </div>
      </div>

      <div
        v-else
        class="border border-dashed border-[var(--color-rule-2)] py-8 text-center font-mono text-xs text-[var(--color-ink-2)]"
      >
        No resources match stock range [{{ minStockThreshold }} - {{ maxStockThreshold }}].
      </div>
    </section>

    <!-- Section 3: Stream Synchronization -->
    <section class="space-y-8 border-t border-[var(--color-rule)] pt-8">
      <div
        class="flex flex-col justify-between gap-4 border-b border-[var(--color-rule)] pb-4 sm:flex-row sm:items-baseline"
      >
        <div class="space-y-1">
          <span
            class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            03 / REAL-TIME STREAM SYNCHRONIZATION
          </span>
          <h2
            class="text-3xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            PubSub Signals vs Periodic Polling
          </h2>
        </div>

        <button
          @click="triggerDbMutation"
          :disabled="isSimulatingMutate"
          class="btn--primary px-6 py-3 text-xs font-semibold uppercase tracking-[0.1em]"
        >
          {{ isSimulatingMutate ? "Broadcasting..." : "Broadcast Stock Mutation Signal" }}
        </button>
      </div>

      <div
        v-if="mutationNotice"
        class="flex items-center justify-between border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] p-4 font-mono text-xs text-[var(--color-ink)]"
      >
        <span>{{ mutationNotice }}</span>
        <span class="font-mono text-[10px] font-bold uppercase text-[var(--color-accent)]"
          >[ PUBSUB EVENT FIRED ]</span
        >
      </div>

      <div class="grid grid-cols-1 items-stretch gap-8 lg:grid-cols-2">
        <!-- 3A: Instant Signal Auto-Refresh -->
        <div
          class="flex flex-col justify-between space-y-6 border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-6"
        >
          <div class="space-y-4">
            <div class="space-y-1 border-b border-[var(--color-rule)] pb-4">
              <span
                class="font-mono text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-accent)]"
                >RECOMMENDED PATTERN</span
              >
              <h3
                class="text-xl font-normal text-[var(--color-ink)]"
                style="font-family: var(--font-display)"
              >
                PubSub Signal Auto-Refresh
              </h3>
              <p class="font-mono text-xs text-[var(--color-ink-2)]">
                autoRefreshOnSignal: "catalog.product_updated"
              </p>
            </div>

            <div class="space-y-2 font-mono text-xs">
              <div
                v-for="item in signalProducts || availableProducts"
                :key="item.id"
                class="flex items-center justify-between border border-[var(--color-rule)] p-3 transition-colors duration-300"
                :class="
                  signalChangedIds.has(item.id)
                    ? 'border-[var(--color-ink)] bg-[var(--color-paper-2)] font-bold'
                    : ''
                "
              >
                <span>{{ item.name }}</span>
                <span class="font-bold text-[var(--color-ink)]">{{ item.stock }} units</span>
              </div>
            </div>
          </div>
        </div>

        <!-- 3B: Fallback Periodic Polling -->
        <div
          class="flex flex-col justify-between space-y-6 border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-6"
        >
          <div class="space-y-4">
            <div class="space-y-1 border-b border-[var(--color-rule)] pb-4">
              <span
                class="font-mono text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
                >FALLBACK PATTERN</span
              >
              <div class="flex items-baseline justify-between">
                <h3
                  class="text-xl font-normal text-[var(--color-ink)]"
                  style="font-family: var(--font-display)"
                >
                  Periodic Polling
                </h3>
                <button
                  @click="isPolling = !isPolling"
                  class="border border-[var(--color-ink)] bg-transparent px-3 py-1 font-mono text-[10px] font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)]"
                >
                  {{ isPolling ? "Pause Polling" : "Start 3s Polling" }}
                </button>
              </div>
              <p class="font-mono text-xs text-[var(--color-ink-2)]">pollIntervalMs: 3000</p>
            </div>

            <div class="space-y-2 font-mono text-xs">
              <div
                v-for="item in polledProducts || availableProducts"
                :key="item.id"
                class="flex items-center justify-between border border-[var(--color-rule)] p-3 transition-colors duration-300"
                :class="
                  pollChangedIds.has(item.id)
                    ? 'border-[var(--color-ink)] bg-[var(--color-paper-2)] font-bold'
                    : ''
                "
              >
                <span>{{ item.name }}</span>
                <span class="font-bold text-[var(--color-ink-2)]">{{ item.stock }} units</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    <SpecimenSourceViewerModal v-model="isSourceModalOpen" specimen-id="query-lookup" />
  </div>
</template>
