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

// Query products dynamically to ensure products are loaded
const { data: queryProducts } = alva.catalog.use_list_products_query(() => ({ query: "" }));

const availableProducts = computed<Product[]>(() => {
  if (props.products && props.products.length > 0) return props.products;
  if (queryProducts.value && queryProducts.value.length > 0) return queryProducts.value;
  return [];
});

const selectedProductId = ref("");

watch(
  availableProducts,
  (list) => {
    if (list.length > 0 && !selectedProductId.value) {
      selectedProductId.value = list[0].id;
    }
  },
  { immediate: true }
);

const selectedProduct = computed(() => {
  return (
    availableProducts.value.find((p) => p.id === selectedProductId.value) ||
    availableProducts.value[0]
  );
});

const OPTIMISTIC_FORM_STATE = {
  IDLE: "idle",
  OPTIMISTIC: "optimistic",
  CONFIRMED: "confirmed",
  ROLLED_BACK: "rolled_back"
} as const;

export type OptimisticFormState = typeof OPTIMISTIC_FORM_STATE[keyof typeof OPTIMISTIC_FORM_STATE];

// UI State
const stockDisplay = ref(50);
const simulateFailure = ref(false);
const statusState = ref<OptimisticFormState>(OPTIMISTIC_FORM_STATE.IDLE);
const statusLog = ref("Ready for interactive optimistic submission.");
const timelineStep = ref(1);

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

watch(
  selectedProduct,
  (prod) => {
    if (prod) {
      stockDisplay.value = prod.stock;
      statusState.value = OPTIMISTIC_FORM_STATE.IDLE;
      statusLog.value = `Selected product: ${prod.name} (Stock: ${prod.stock})`;
      timelineStep.value = 1;
      addLog("rpc", `Initialized mutation target: ${prod.name} (Stock: ${prod.stock})`);
    }
  },
  { immediate: true }
);

const stockForm = alva.catalog.use_adjust_stock_form({
  initialValues: {
    id: selectedProduct.value?.id || "",
    stock: stockDisplay.value
  },
  onOptimisticSubmit: (formData) => {
    const previousStock = stockDisplay.value;

    // 1. Instant local UI update
    stockDisplay.value = formData.stock ?? previousStock;
    statusState.value = OPTIMISTIC_FORM_STATE.OPTIMISTIC;
    statusLog.value = `⚡ Step 1/3 (0ms): Local state updated to ${stockDisplay.value} units!`;
    timelineStep.value = 2;

    addLog("optimistic", `Local UI state updated to ${stockDisplay.value} units (0ms execution)`);

    // 2. Return rollback function if server fails
    return () => {
      stockDisplay.value = previousStock;
      statusState.value = OPTIMISTIC_FORM_STATE.ROLLED_BACK;
      statusLog.value = `❌ Step 3/3: Server validation failed! Restored inventory state to ${previousStock} units.`;
      timelineStep.value = 4;

      addLog(
        "rollback",
        `Server validation error: Stock cannot be negative. Executed UI rollback to ${previousStock} units.`
      );
    };
  }
});

const handleAdjustStock = async (delta: number) => {
  if (!selectedProduct.value) return;

  const targetStock = stockDisplay.value + delta;
  const submitStock = simulateFailure.value ? -15 : Math.max(0, targetStock);

  stockForm.field("id").value.value = selectedProduct.value.id;
  stockForm.field("stock").value.value = submitStock;
  if (stockForm.values) {
    stockForm.values.id = selectedProduct.value.id;
    stockForm.values.stock = submitStock;
  }

  timelineStep.value = 3;
  statusLog.value = `⏳ Step 2/3: Dispatching RPC request over WebSocket...`;
  addLog("rpc", `Dispatching "catalog.adjust_stock" over WebSocket (target value: ${submitStock})`);

  const result = await stockForm.submit();

  if (result.ok) {
    const resultData =
      result && "data" in result && typeof result.data === "object" && result.data !== null
        ? result.data
        : null;
    const confirmedStock =
      resultData && "stock" in resultData && typeof resultData.stock === "number"
        ? resultData.stock
        : submitStock;
    stockDisplay.value = confirmedStock;
    statusState.value = OPTIMISTIC_FORM_STATE.CONFIRMED;
    statusLog.value = `✔ Step 3/3: Server confirmed DB write! Stock successfully locked at ${confirmedStock} units.`;
    timelineStep.value = 4;
    addLog("confirmed", `Server DB write confirmed. Stock locked at ${confirmedStock} units.`);
  }
};
</script>

<template>
  <div class="w-full space-y-16 py-4" data-testid="demo-optimistic-form-vue">
    <!-- Broadsheet Header -->
    <header class="space-y-6 border-b border-[var(--color-rule)] pb-12">
      <div class="space-y-1">
        <span
          class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          № 05 — OPTIMISTIC MUTATION ENGINE
        </span>
        <p
          class="text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          Zero-Latency UI Execution Specimen
        </p>
      </div>
      <h1
        class="text-5xl font-normal text-[var(--color-ink)]"
        style="font-family: var(--font-display); line-height: 1.1"
      >
        Optimistic Form UI &amp; State Rollback.
      </h1>
      <div class="flex flex-col justify-between gap-6 sm:flex-row sm:items-end">
        <p class="max-w-[65ch] text-lg text-[var(--color-ink-2)]" style="line-height: 1.7">
          Execute zero-latency client state mutations with <code>onOptimisticSubmit</code> hooks,
          accompanied by automatic state rollback when server validations fail.
        </p>
        <Button variant="specimen" @click="isSourceModalOpen = true">
          <span>⚡ INSPECT SPECIMEN CODE</span>
        </Button>
      </div>
    </header>

    <!-- Main Broadsheet Section -->
    <section class="space-y-8 border-t border-[var(--color-rule)] pt-8">
      <!-- Target Product Bar -->
      <div
        class="flex flex-col justify-between gap-4 border-b border-[var(--color-rule)] pb-4 sm:flex-row sm:items-baseline"
      >
        <div class="space-y-1">
          <span
            class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            01 / SPECIMEN SELECTION
          </span>
          <h2
            class="text-3xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            Inventory Mutation Target
          </h2>
        </div>

        <select
          v-model="selectedProductId"
          class="min-w-[260px] rounded-none border-0 border-b border-[var(--color-rule-2)] bg-[var(--color-paper)] px-2 py-2 font-mono text-sm text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0"
        >
          <option
            v-for="p in availableProducts"
            :key="p.id"
            :value="p.id"
            class="bg-[var(--color-paper)] text-[var(--color-ink)]"
          >
            {{ p.name }} (Stock: {{ p.stock }})
          </option>
        </select>
      </div>

      <!-- Main Broadsheet Card -->
      <div class="space-y-10 border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-8">
        <!-- Live Product Header & Inventory Count -->
        <div
          class="flex flex-col items-baseline justify-between gap-6 border-b border-[var(--color-rule)] pb-8 sm:flex-row"
        >
          <div class="flex items-center gap-6">
            <img
              v-if="selectedProduct?.media_reference"
              :src="'/images/' + selectedProduct.media_reference"
              :alt="selectedProduct.name"
              class="h-24 w-24 border border-[var(--color-rule-2)] bg-white object-contain p-2"
            />
            <div class="space-y-2">
              <h3
                class="text-3xl font-normal text-[var(--color-ink)]"
                style="font-family: var(--font-display)"
              >
                {{ selectedProduct?.name || "Product Stock" }}
              </h3>
              <p class="font-mono text-xs text-[var(--color-ink-2)]">
                Resource Primary Key: {{ selectedProduct?.id }}
              </p>
            </div>
          </div>

          <!-- Stock Counter Display -->
          <div class="space-y-1 text-right">
            <div class="font-mono text-xs uppercase tracking-[0.15em] text-[var(--color-ink-2)]">
              Live Inventory State
            </div>
            <div
              class="font-mono text-6xl font-normal transition-all duration-300"
              :class="{
                'text-[var(--color-ink)]': statusState === 'idle',
                'font-bold text-blue-600': statusState === 'optimistic',
                'font-bold text-emerald-600': statusState === 'confirmed',
                'font-bold text-red-600': statusState === 'rolled_back'
              }"
            >
              {{ stockDisplay }}
              <span class="text-base font-normal text-[var(--color-ink-2)]">units</span>
            </div>
          </div>
        </div>

        <!-- Execution Lifecycle Flow -->
        <div class="space-y-4">
          <div
            class="font-mono text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
          >
            02 / EXECUTION LIFECYCLE PROTOCOL
          </div>
          <div class="grid grid-cols-1 gap-4 text-center font-mono text-xs md:grid-cols-3">
            <div
              class="border p-4 transition-colors"
              :class="
                timelineStep >= 2
                  ? 'border-[var(--color-ink)] bg-[var(--color-paper-2)] font-bold text-[var(--color-ink)]'
                  : 'border-[var(--color-rule-2)] text-[var(--color-ink-2)]'
              "
            >
              1. Optimistic Local (0ms)
            </div>
            <div
              class="border p-4 transition-colors"
              :class="
                timelineStep >= 3
                  ? 'border-[var(--color-ink)] bg-[var(--color-paper-2)] font-bold text-[var(--color-ink)]'
                  : 'border-[var(--color-rule-2)] text-[var(--color-ink-2)]'
              "
            >
              2. WebSocket RPC Dispatch
            </div>
            <div
              class="border p-4 transition-colors"
              :class="
                statusState === OPTIMISTIC_FORM_STATE.CONFIRMED
                  ? 'border-emerald-600 font-bold text-emerald-600'
                  : statusState === OPTIMISTIC_FORM_STATE.ROLLED_BACK
                    ? 'border-red-600 font-bold text-red-600'
                    : 'border-[var(--color-rule-2)] text-[var(--color-ink-2)]'
              "
            >
              3.
              {{
                statusState === OPTIMISTIC_FORM_STATE.ROLLED_BACK
                  ? "Rollback State"
                  : statusState === OPTIMISTIC_FORM_STATE.CONFIRMED
                    ? "Server Confirmed"
                    : "Result State"
              }}
            </div>
          </div>
        </div>

        <!-- Controls -->
        <div class="space-y-6">
          <div
            class="flex items-center gap-3 border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] p-4"
          >
            <input
              type="checkbox"
              v-model="simulateFailure"
              id="sim-fail"
              class="h-4 w-4 cursor-pointer accent-[var(--color-ink)]"
            />
            <label
              for="sim-fail"
              class="cursor-pointer font-mono text-xs font-semibold text-[var(--color-ink)]"
            >
              ⚠️ SIMULATE SERVER VALIDATION FAILURE (submits negative stock -15 to trigger automatic
              UI rollback)
            </label>
          </div>

          <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
            <button
              @click="handleAdjustStock(1)"
              class="border border-[var(--color-ink)] bg-transparent py-4 font-mono text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)] transition-colors hover:bg-[var(--color-ink)] hover:text-[var(--color-paper)]"
            >
              +1 Stock
            </button>
            <button
              @click="handleAdjustStock(10)"
              class="btn--primary py-4 text-xs font-semibold uppercase tracking-[0.1em]"
            >
              +10 Stock
            </button>
            <button
              @click="handleAdjustStock(-1)"
              class="border border-[var(--color-ink)] bg-transparent py-4 font-mono text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)] transition-colors hover:bg-[var(--color-ink)] hover:text-[var(--color-paper)]"
            >
              -1 Stock
            </button>
            <button
              @click="handleAdjustStock(-10)"
              class="border border-[var(--color-ink)] bg-transparent py-4 font-mono text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)] transition-colors hover:bg-[var(--color-ink)] hover:text-[var(--color-paper)]"
            >
              -10 Stock
            </button>
          </div>
        </div>

        <!-- Broadsheet Code Telemetry Card -->
        <div
          class="space-y-3 border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] p-4 font-mono"
        >
          <div
            class="flex items-center justify-between border-b border-[var(--color-rule)] pb-2 text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
          >
            <span>03 / WEBSOCKET TELEMETRY LOG</span>
            <span>CHANNEL: ALVA:DISPATCH</span>
          </div>
          <div class="min-h-[130px] space-y-1 overflow-x-auto pt-1 text-xs leading-relaxed">
            <div
              v-if="telemetryLogs.length === 0"
              class="text-[11px] italic text-[var(--color-ink-2)]"
            >
              Awaiting interactive stock mutation...
            </div>
            <div
              v-for="log in telemetryLogs"
              :key="log.id"
              class="border-[var(--color-rule)]/40 flex items-start gap-3 border-b py-1 last:border-0"
            >
              <span class="min-w-[70px] text-[11px] text-[var(--color-ink-2)]">{{ log.time }}</span>
              <span
                class="min-w-[85px] text-[10px] font-bold uppercase tracking-[0.1em]"
                :class="{
                  'text-sky-600 dark:text-sky-400': log.type === 'optimistic',
                  'text-amber-600 dark:text-amber-400': log.type === 'rpc',
                  'text-emerald-600 dark:text-emerald-400': log.type === 'confirmed',
                  'text-rose-600 dark:text-rose-400': log.type === 'rollback'
                }"
              >
                [{{ log.type }}]
              </span>
              <span class="flex-1 text-[11px] font-semibold text-[var(--color-ink)]">{{
                log.text
              }}</span>
            </div>
          </div>
        </div>
      </div>
    </section>
    <SpecimenSourceViewerModal v-model="isSourceModalOpen" specimen-id="optimistic-form" />
  </div>
</template>
