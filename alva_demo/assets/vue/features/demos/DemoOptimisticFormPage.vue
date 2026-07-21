<script setup lang="ts">
import { ref, computed, watch } from "vue";
import { useAlva } from "../../../js/alva";
import type { Product } from "../../../js/alva/types";
import Button from "../../shared/ui/button/Button.vue";

const props = defineProps<{
  products?: Product[];
}>();

const alva = useAlva();

// Query products dynamically to ensure products are loaded
const { data: queryProducts } = alva.catalog.use_list_products_query(() => ({ query: "" }));

const availableProducts = computed<Product[]>(() => {
  if (props.products && props.products.length > 0) return props.products;
  if (queryProducts.value && queryProducts.value.length > 0) return queryProducts.value;
  return [];
});

const selectedProductId = ref<string>("");

watch(availableProducts, (list) => {
  if (list.length > 0 && !selectedProductId.value) {
    selectedProductId.value = list[0].id;
  }
}, { immediate: true });

const selectedProduct = computed(() => {
  return availableProducts.value.find((p) => p.id === selectedProductId.value) || availableProducts.value[0];
});

// UI State
const stockDisplay = ref(50);
const simulateFailure = ref(false);
const statusState = ref<"idle" | "optimistic" | "confirmed" | "rolled_back">("idle");
const statusLog = ref<string>("Ready for interactive optimistic submission.");
const timelineStep = ref<number>(1);

// Telemetry Log
type TelemetryLog = {
  id: string;
  time: string;
  type: "optimistic" | "rpc" | "confirmed" | "rollback";
  text: string;
};

const telemetryLogs = ref<TelemetryLog[]>([]);

const addLog = (type: TelemetryLog["type"], text: string) => {
  telemetryLogs.value.unshift({
    id: Math.random().toString(36).substring(7),
    time: new Date().toLocaleTimeString(),
    type,
    text
  });
  if (telemetryLogs.value.length > 5) {
    telemetryLogs.value.pop();
  }
};

watch(selectedProduct, (prod) => {
  if (prod) {
    stockDisplay.value = prod.stock;
    statusState.value = "idle";
    statusLog.value = `Selected product: ${prod.name} (Stock: ${prod.stock})`;
    timelineStep.value = 1;
    addLog("rpc", `Initialized mutation target: ${prod.name} (Stock: ${prod.stock})`);
  }
}, { immediate: true });

const stockForm = alva.catalog.use_adjust_stock_form({
  initialValues: {
    id: selectedProduct.value?.id || "",
    stock: stockDisplay.value
  },
  onOptimisticSubmit: (formData) => {
    const previousStock = stockDisplay.value;
    
    // 1. Instant local UI update
    stockDisplay.value = formData.stock ?? previousStock;
    statusState.value = "optimistic";
    statusLog.value = `⚡ Step 1/3 (0ms): Local state updated to ${stockDisplay.value} units!`;
    timelineStep.value = 2;

    addLog("optimistic", `Local UI state updated to ${stockDisplay.value} units (0ms execution)`);

    // 2. Return rollback function if server fails
    return () => {
      stockDisplay.value = previousStock;
      statusState.value = "rolled_back";
      statusLog.value = `❌ Step 3/3: Server validation failed! Restored inventory state to ${previousStock} units.`;
      timelineStep.value = 4;

      addLog("rollback", `Server validation error: Stock cannot be negative. Executed UI rollback to ${previousStock} units.`);
    };
  }
});

const handleAdjustStock = async (delta: number) => {
  if (!selectedProduct.value) return;

  const targetStock = stockDisplay.value + delta;
  const submitStock = simulateFailure.value ? -15 : Math.max(0, targetStock);

  stockForm.field("id").value.value = selectedProduct.value.id;
  stockForm.field("stock").value.value = submitStock;

  timelineStep.value = 3;
  statusLog.value = `⏳ Step 2/3: Dispatching RPC request over WebSocket...`;
  addLog("rpc", `Dispatching "catalog.adjust_stock" over WebSocket (target value: ${submitStock})`);

  const result = await stockForm.submit();

  if (result.ok) {
    statusState.value = "confirmed";
    statusLog.value = `✔ Step 3/3: Server confirmed DB write! Stock successfully locked at ${stockDisplay.value} units.`;
    timelineStep.value = 4;
    addLog("confirmed", `Server DB write confirmed. Stock locked at ${stockDisplay.value} units.`);
  }
};
</script>

<template>
  <div class="max-w-5xl mx-auto py-12 px-6 lg:px-12 space-y-16" data-testid="demo-optimistic-form-vue">
    <!-- Broadsheet Header -->
    <header class="space-y-6 pb-12 border-b border-[var(--color-rule)]">
      <div class="space-y-1">
        <span class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          № 05 — OPTIMISTIC MUTATION ENGINE
        </span>
        <p class="text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          Zero-Latency UI Execution Specimen
        </p>
      </div>
      <h1 class="text-5xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display); line-height: 1.1;">
        Optimistic Form UI &amp; State Rollback.
      </h1>
      <p class="text-lg text-[var(--color-ink-2)] max-w-[65ch]" style="line-height: 1.7;">
        Execute zero-latency client state mutations with <code>onOptimisticSubmit</code> hooks, accompanied by automatic state rollback when server validations fail.
      </p>
    </header>

    <!-- Main Broadsheet Section -->
    <section class="space-y-8 border-t border-[var(--color-rule)] pt-8">
      <!-- Target Product Bar -->
      <div class="flex flex-col sm:flex-row sm:items-baseline justify-between border-b border-[var(--color-rule)] pb-4 gap-4">
        <div class="space-y-1">
          <span class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
            01 / SPECIMEN SELECTION
          </span>
          <h2 class="text-3xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">
            Inventory Mutation Target
          </h2>
        </div>

        <select v-model="selectedProductId" class="rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 py-2 text-sm text-[var(--color-ink)] font-mono focus:border-[var(--color-ink)] focus:outline-none focus:ring-0 min-w-[260px]">
          <option v-for="p in availableProducts" :key="p.id" :value="p.id">
            {{ p.name }} (Stock: {{ p.stock }})
          </option>
        </select>
      </div>

      <!-- Main Broadsheet Card -->
      <div class="border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-8 space-y-10">
        <!-- Live Product Header & Inventory Count -->
        <div class="flex flex-col sm:flex-row items-baseline justify-between border-b border-[var(--color-rule)] pb-8 gap-6">
          <div class="flex items-center gap-6">
            <img 
              v-if="selectedProduct?.media_reference" 
              :src="'/images/' + selectedProduct.media_reference" 
              :alt="selectedProduct.name"
              class="h-24 w-24 object-contain border border-[var(--color-rule-2)] bg-white p-2"
            />
            <div class="space-y-2">
              <h3 class="text-3xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">
                {{ selectedProduct?.name || "Product Stock" }}
              </h3>
              <p class="text-xs font-mono text-[var(--color-ink-2)]">Resource Primary Key: {{ selectedProduct?.id }}</p>
            </div>
          </div>

          <!-- Stock Counter Display -->
          <div class="text-right space-y-1">
            <div class="text-xs uppercase tracking-[0.15em] text-[var(--color-ink-2)] font-mono">Live Inventory State</div>
            <div 
              class="text-6xl font-normal transition-all duration-300 font-mono"
              :class="{
                'text-[var(--color-ink)]': statusState === 'idle',
                'text-blue-600 font-bold': statusState === 'optimistic',
                'text-emerald-600 font-bold': statusState === 'confirmed',
                'text-red-600 font-bold': statusState === 'rolled_back'
              }"
            >
              {{ stockDisplay }}
              <span class="text-base font-normal text-[var(--color-ink-2)]">units</span>
            </div>
          </div>
        </div>

        <!-- Execution Lifecycle Flow -->
        <div class="space-y-4">
          <div class="text-xs font-mono font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]">
            02 / EXECUTION LIFECYCLE PROTOCOL
          </div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 font-mono text-xs text-center">
            <div 
              class="p-4 border transition-colors"
              :class="timelineStep >= 2 ? 'border-[var(--color-ink)] bg-[var(--color-paper-2)] font-bold text-[var(--color-ink)]' : 'border-[var(--color-rule-2)] text-[var(--color-ink-2)]'"
            >
              1. Optimistic Local (0ms)
            </div>
            <div 
              class="p-4 border transition-colors"
              :class="timelineStep >= 3 ? 'border-[var(--color-ink)] bg-[var(--color-paper-2)] font-bold text-[var(--color-ink)]' : 'border-[var(--color-rule-2)] text-[var(--color-ink-2)]'"
            >
              2. WebSocket RPC Dispatch
            </div>
            <div 
              class="p-4 border transition-colors"
              :class="statusState === 'confirmed' ? 'border-emerald-600 font-bold text-emerald-600' : statusState === 'rolled_back' ? 'border-red-600 font-bold text-red-600' : 'border-[var(--color-rule-2)] text-[var(--color-ink-2)]'"
            >
              3. {{ statusState === 'rolled_back' ? 'Rollback State' : statusState === 'confirmed' ? 'Server Confirmed' : 'Result State' }}
            </div>
          </div>
        </div>

        <!-- Controls -->
        <div class="space-y-6">
          <div class="flex items-center gap-3 p-4 border border-[var(--color-rule-2)] bg-[var(--color-paper-2)]">
            <input type="checkbox" v-model="simulateFailure" id="sim-fail" class="h-4 w-4 accent-[var(--color-ink)] cursor-pointer" />
            <label for="sim-fail" class="text-xs font-mono font-semibold text-[var(--color-ink)] cursor-pointer">
              ⚠️ SIMULATE SERVER VALIDATION FAILURE (submits negative stock -15 to trigger automatic UI rollback)
            </label>
          </div>

          <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
            <button @click="handleAdjustStock(1)" class="border border-[var(--color-ink)] bg-transparent py-4 text-xs font-semibold font-mono uppercase tracking-[0.1em] text-[var(--color-ink)] transition-colors hover:bg-[var(--color-ink)] hover:text-[var(--color-paper)]">
              +1 Stock
            </button>
            <button @click="handleAdjustStock(10)" class="btn--primary py-4 text-xs font-semibold uppercase tracking-[0.1em]">
              +10 Stock
            </button>
            <button @click="handleAdjustStock(-1)" class="border border-[var(--color-ink)] bg-transparent py-4 text-xs font-semibold font-mono uppercase tracking-[0.1em] text-[var(--color-ink)] transition-colors hover:bg-[var(--color-ink)] hover:text-[var(--color-paper)]">
              -1 Stock
            </button>
            <button @click="handleAdjustStock(-10)" class="border border-[var(--color-ink)] bg-transparent py-4 text-xs font-semibold font-mono uppercase tracking-[0.1em] text-[var(--color-ink)] transition-colors hover:bg-[var(--color-ink)] hover:text-[var(--color-paper)]">
              -10 Stock
            </button>
          </div>
        </div>

        <!-- Broadsheet Code Telemetry Card -->
        <div class="space-y-2">
          <div class="text-xs font-mono font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)] flex justify-between">
            <span>03 / WEBSOCKET TELEMETRY LOG</span>
            <span>Channel: alva:dispatch</span>
          </div>
          <div class="code-card p-6 text-xs leading-relaxed overflow-x-auto min-h-[140px]">
            <div v-if="telemetryLogs.length === 0" class="text-slate-500 italic">Awaiting interactive stock mutation...</div>
            <div v-for="log in telemetryLogs" :key="log.id" class="flex gap-4 items-start py-1 border-b border-slate-800/50 last:border-0 font-mono">
              <span class="text-slate-500">{{ log.time }}</span>
              <span 
                class="uppercase font-bold tracking-[0.1em] text-[10px]"
                :class="{
                  'text-blue-400': log.type === 'optimistic',
                  'text-amber-400': log.type === 'rpc',
                  'text-emerald-400': log.type === 'confirmed',
                  'text-red-400': log.type === 'rollback'
                }"
              >
                [{{ log.type }}]
              </span>
              <span class="text-slate-300 flex-1">{{ log.text }}</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
