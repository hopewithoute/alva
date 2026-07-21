<script setup lang="ts">
import { ref, computed, watch } from "vue";
import { useAlva } from "../../../js/alva";
import type { Product } from "../../../js/alva/types";
import Button from "../../shared/ui/button/Button.vue";

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
const selectedProductId = ref<string>("");

watch(availableProducts, (list) => {
  if (list.length > 0 && !selectedProductId.value) {
    selectedProductId.value = list[0].id;
  }
}, { immediate: true });

const { data: selectedProduct, loading: loadingSingle, refetch: refetchSingle } = alva.catalog.use_get_product_by_id(selectedProductId);

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

watch(signalProducts, (newList) => {
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
}, { immediate: true });

// Query 3B: Periodic Fallback Polling (3000ms updates)
const pollCount = ref(0);
const lastPolledTime = ref<string | null>(null);

const { data: polledProducts } = alva.catalog.use_list_products_query(
  () => ({ query: "" }),
  { pollIntervalMs: () => (isPolling.value ? 3000 : 0) }
);

const previousPollStock = ref<Record<string, number>>({});
const pollChangedIds = ref<Set<string>>(new Set());

watch(polledProducts, (newList) => {
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
}, { immediate: true });

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

const activeTab = ref<"card" | "json">("card");
</script>

<template>
  <div class="max-w-5xl mx-auto py-12 px-6 lg:px-12 space-y-16" data-testid="demo-query-lookup-vue">
    <!-- Broadsheet Header -->
    <header class="space-y-6 pb-12 border-b border-[var(--color-rule)]">
      <div class="space-y-1">
        <span class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          № 04 — QUERY ENGINE SPECIMEN
        </span>
        <p class="text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          Declarative Data Access Architecture
        </p>
      </div>
      <h1 class="text-5xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display); line-height: 1.1;">
        Single-Record Lookups &amp; Reactive Query Filtering.
      </h1>
      <p class="text-lg text-[var(--color-ink-2)] max-w-[65ch]" style="line-height: 1.7;">
        Retrieve typed DTO entities by primary key, apply dynamic AST range filters over WebSockets, and compare real-time PubSub signal auto-refreshing against fallback polling.
      </p>
    </header>

    <!-- Section 1: Single-Record Lookup -->
    <section class="space-y-6 border-t border-[var(--color-rule)] pt-8">
      <div class="flex flex-col sm:flex-row sm:items-baseline justify-between border-b border-[var(--color-rule)] pb-4 gap-4">
        <div class="space-y-1">
          <span class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
            01 / RESOURCE DTO FETCHING
          </span>
          <h2 class="text-3xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">
            Single-Entity Lookup (<code>use_get_product_by_id</code>)
          </h2>
        </div>
        
        <div class="flex items-center gap-4 font-mono text-xs">
          <button 
            @click="activeTab = 'card'"
            class="uppercase tracking-[0.1em] py-1 border-b transition-colors"
            :class="activeTab === 'card' ? 'border-[var(--color-ink)] text-[var(--color-ink)] font-bold' : 'border-transparent text-[var(--color-ink-2)] hover:text-[var(--color-ink)]'"
          >
            DTO View
          </button>
          <button 
            @click="activeTab = 'json'"
            class="uppercase tracking-[0.1em] py-1 border-b transition-colors"
            :class="activeTab === 'json' ? 'border-[var(--color-ink)] text-[var(--color-ink)] font-bold' : 'border-transparent text-[var(--color-ink-2)] hover:text-[var(--color-ink)]'"
          >
            Raw DTO Payload
          </button>
        </div>
      </div>

      <div class="flex flex-col sm:flex-row sm:items-center gap-4 py-2">
        <label class="text-xs font-mono font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)]">Select Resource ID:</label>
        <select v-model="selectedProductId" class="rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 py-2 text-sm text-[var(--color-ink)] font-mono focus:border-[var(--color-ink)] focus:outline-none focus:ring-0">
          <option v-for="p in availableProducts" :key="p.id" :value="p.id">
            {{ p.name }} ({{ p.id.slice(0, 8) }}...)
          </option>
        </select>
        <span v-if="loadingSingle" class="text-xs font-mono text-[var(--color-accent)] animate-pulse">Fetching entity...</span>
      </div>

      <!-- Broadsheet DTO Card -->
      <div v-if="selectedProduct && activeTab === 'card'" class="border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-8 flex flex-col sm:flex-row gap-8 items-start">
        <img 
          v-if="selectedProduct.media_reference" 
          :src="'/images/' + selectedProduct.media_reference" 
          :alt="selectedProduct.name" 
          class="h-28 w-28 object-contain border border-[var(--color-rule-2)] bg-white p-2 flex-shrink-0" 
        />
        <div v-else class="h-28 w-28 border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] flex items-center justify-center flex-shrink-0 font-mono text-sm font-bold">
          {{ selectedProduct.name.slice(0, 2).toUpperCase() }}
        </div>

        <div class="space-y-3 font-mono text-xs flex-1 w-full">
          <div class="flex items-baseline justify-between border-b border-[var(--color-rule)] pb-4">
            <div>
              <h3 class="text-2xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">{{ selectedProduct.name }}</h3>
              <p class="text-[11px] text-[var(--color-ink-2)] mt-1">Resource Primary Key: {{ selectedProduct.id }}</p>
            </div>
            <span class="text-xs font-bold uppercase tracking-[0.1em] text-[var(--color-accent)] font-mono">
              {{ selectedProduct.stock }} Units Available
            </span>
          </div>

          <p class="text-[var(--color-ink-2)] text-base font-sans leading-relaxed pt-2">{{ selectedProduct.description }}</p>
        </div>
      </div>

      <!-- Broadsheet Raw Code Card -->
      <div v-else-if="selectedProduct && activeTab === 'json'" class="code-card p-6 overflow-x-auto text-xs leading-relaxed">
        <pre class="text-emerald-400">{{ JSON.stringify(selectedProduct, null, 2) }}</pre>
      </div>
    </section>

    <!-- Section 2: Dynamic Query Filtering -->
    <section class="space-y-8 border-t border-[var(--color-rule)] pt-8">
      <div class="flex flex-col sm:flex-row sm:items-baseline justify-between border-b border-[var(--color-rule)] pb-4 gap-4">
        <div class="space-y-1">
          <span class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
            02 / DYNAMIC AST QUERY FILTERING
          </span>
          <h2 class="text-3xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">
            Reactive Stock Threshold Filtering
          </h2>
        </div>
        <span class="text-xs font-mono text-[var(--color-ink-2)] uppercase tracking-[0.1em]">
          Matching Entities: {{ filteredProducts?.length || 0 }}
        </span>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-8 p-6 border border-[var(--color-rule-2)] bg-[var(--color-paper-2)]">
        <div>
          <label class="block text-xs font-mono font-semibold uppercase tracking-[0.1em] text-[var(--color-ink-2)] mb-2">Search Keyword:</label>
          <input v-model="searchPattern" placeholder="Filter by product name..." class="w-full rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 py-2 text-sm text-[var(--color-ink)] font-mono focus:border-[var(--color-ink)] focus:outline-none focus:ring-0" />
        </div>

        <div>
          <div class="flex justify-between text-xs font-mono text-[var(--color-ink-2)] mb-2 uppercase tracking-[0.1em]">
            <span>Min Inventory:</span>
            <strong class="text-[var(--color-ink)] font-bold">{{ minStockThreshold }} units</strong>
          </div>
          <input type="range" min="-50" max="100" v-model.number="minStockThreshold" class="w-full accent-[var(--color-ink)] cursor-pointer" />
        </div>

        <div>
          <div class="flex justify-between text-xs font-mono text-[var(--color-ink-2)] mb-2 uppercase tracking-[0.1em]">
            <span>Max Inventory:</span>
            <strong class="text-[var(--color-ink)] font-bold">{{ maxStockThreshold }} units</strong>
          </div>
          <input type="range" min="-50" max="100" v-model.number="maxStockThreshold" class="w-full accent-[var(--color-ink)] cursor-pointer" />
        </div>
      </div>

      <div v-if="loadingFiltered" class="text-xs text-[var(--color-accent)] animate-pulse font-mono py-2">Executing query evaluation...</div>

      <div v-else-if="filteredProducts && filteredProducts.length > 0" class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6">
        <div 
          v-for="item in filteredProducts" 
          :key="item.id" 
          class="border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-5 space-y-2 transition-colors duration-300"
          :class="{ 'border-[var(--color-ink)] bg-[var(--color-paper-2)]': signalChangedIds.has(item.id) }"
        >
          <div class="font-normal text-lg text-[var(--color-ink)]" style="font-family: var(--font-display)">{{ item.name }}</div>
          <div class="flex justify-between text-xs font-mono text-[var(--color-ink-2)] border-t border-[var(--color-rule)] pt-2">
            <span>Inventory Level:</span>
            <span class="font-bold text-[var(--color-ink)]">{{ item.stock }} units</span>
          </div>
        </div>
      </div>

      <div v-else class="text-xs text-[var(--color-ink-2)] font-mono py-8 text-center border border-dashed border-[var(--color-rule-2)]">
        No resources match stock range [{{ minStockThreshold }} - {{ maxStockThreshold }}].
      </div>
    </section>

    <!-- Section 3: Stream Synchronization -->
    <section class="space-y-8 border-t border-[var(--color-rule)] pt-8">
      <div class="flex flex-col sm:flex-row sm:items-baseline justify-between border-b border-[var(--color-rule)] pb-4 gap-4">
        <div class="space-y-1">
          <span class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
            03 / REAL-TIME STREAM SYNCHRONIZATION
          </span>
          <h2 class="text-3xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">
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

      <div v-if="mutationNotice" class="p-4 font-mono text-xs border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] text-[var(--color-ink)] flex items-center justify-between">
        <span>{{ mutationNotice }}</span>
        <span class="text-[10px] uppercase font-bold text-[var(--color-accent)] font-mono">[ PUBSUB EVENT FIRED ]</span>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 items-stretch">
        <!-- 3A: Instant Signal Auto-Refresh -->
        <div class="border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-6 space-y-6 flex flex-col justify-between">
          <div class="space-y-4">
            <div class="border-b border-[var(--color-rule)] pb-4 space-y-1">
              <span class="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-accent)] font-mono">RECOMMENDED PATTERN</span>
              <h3 class="text-xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">PubSub Signal Auto-Refresh</h3>
              <p class="text-xs font-mono text-[var(--color-ink-2)]">autoRefreshOnSignal: "catalog.product_updated"</p>
            </div>

            <div class="space-y-2 font-mono text-xs">
              <div 
                v-for="item in signalProducts || availableProducts" 
                :key="item.id" 
                class="border border-[var(--color-rule)] p-3 flex justify-between items-center transition-colors duration-300"
                :class="signalChangedIds.has(item.id) ? 'border-[var(--color-ink)] bg-[var(--color-paper-2)] font-bold' : ''"
              >
                <span>{{ item.name }}</span>
                <span class="font-bold text-[var(--color-ink)]">{{ item.stock }} units</span>
              </div>
            </div>
          </div>
        </div>

        <!-- 3B: Fallback Periodic Polling -->
        <div class="border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-6 space-y-6 flex flex-col justify-between">
          <div class="space-y-4">
            <div class="border-b border-[var(--color-rule)] pb-4 space-y-1">
              <span class="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)] font-mono">FALLBACK PATTERN</span>
              <div class="flex justify-between items-baseline">
                <h3 class="text-xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">Periodic Polling</h3>
                <button 
                  @click="isPolling = !isPolling" 
                  class="border border-[var(--color-ink)] bg-transparent px-3 py-1 text-[10px] font-semibold font-mono uppercase tracking-[0.1em] text-[var(--color-ink)]"
                >
                  {{ isPolling ? "Pause Polling" : "Start 3s Polling" }}
                </button>
              </div>
              <p class="text-xs font-mono text-[var(--color-ink-2)]">pollIntervalMs: 3000</p>
            </div>

            <div class="space-y-2 font-mono text-xs">
              <div 
                v-for="item in polledProducts || availableProducts" 
                :key="item.id" 
                class="border border-[var(--color-rule)] p-3 flex justify-between items-center transition-colors duration-300"
                :class="pollChangedIds.has(item.id) ? 'border-[var(--color-ink)] bg-[var(--color-paper-2)] font-bold' : ''"
              >
                <span>{{ item.name }}</span>
                <span class="font-bold text-[var(--color-ink-2)]">{{ item.stock }} units</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
