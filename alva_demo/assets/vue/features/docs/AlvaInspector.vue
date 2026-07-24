<script setup lang="ts">
import { ref, onMounted, onUnmounted } from "vue";

declare global {
  interface Window {
    __ALVA_RECORD_TELEMETRY__?: (event: string, durationMs: number, ok: boolean) => void;
  }
}

const isExpanded = ref(false);
const logs = ref<
  Array<{
    id: number;
    event: string;
    durationMs: number;
    timestamp: string;
    ok: boolean;
    type?: string;
  }>
>([]);
let nextId = 1;

const recordEvent = (
  event: string,
  durationMs = 0,
  ok = true,
  type = "api"
) => {
  logs.value.unshift({
    id: nextId++,
    event,
    durationMs,
    timestamp: new Date().toLocaleTimeString(),
    ok,
    type
  });
  if (logs.value.length > 30) logs.value.pop();
};

// Global event interceptor for Alva inspector metrics
if (typeof window !== "undefined") {
  window.__ALVA_RECORD_TELEMETRY__ = (event: string, durationMs: number, ok: boolean) => {
    recordEvent(event, durationMs, ok, "api");
  };
}

const handlePopState = () => {
  if (typeof window !== "undefined") {
    recordEvent(`router.navigate: ${window.location.pathname}`, 1, true, "route");
  }
};

const handleAlvaSignal = (e: Event) => {
  const customDetail =
    "detail" in e && typeof e.detail === "object" && e.detail !== null ? e.detail : null;
  const signalName =
    customDetail && "name" in customDetail && typeof customDetail.name === "string"
      ? customDetail.name
      : "pubsub.signal";
  recordEvent(`signal.receive: ${signalName}`, 2, true, "signal");
};

onMounted(() => {
  if (typeof window !== "undefined") {
    window.addEventListener("popstate", handlePopState);
    window.addEventListener("alva:signal", handleAlvaSignal);
  }
});

onUnmounted(() => {
  if (typeof window !== "undefined") {
    window.removeEventListener("popstate", handlePopState);
    window.removeEventListener("alva:signal", handleAlvaSignal);
  }
});

const clearLogs = () => {
  logs.value = [];
};
</script>

<template>
  <div class="fixed bottom-4 right-4 z-50 font-mono text-xs shadow-2xl">
    <!-- Toggle Pill -->
    <button
      @click="isExpanded = !isExpanded"
      class="flex items-center gap-2 rounded-full border border-emerald-500/30 bg-slate-900 px-3 py-1.5 text-emerald-400 backdrop-blur-md transition-all hover:border-emerald-400"
    >
      <span class="relative flex h-2 w-2">
        <span
          class="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75"
        ></span>
        <span class="relative inline-flex h-2 w-2 rounded-full bg-emerald-500"></span>
      </span>
      <span class="font-bold tracking-wider">ALVA INSPECTOR</span>
      <span class="rounded bg-emerald-950 px-1.5 py-0.5 text-[10px] text-emerald-300">
        {{ logs.length }} events
      </span>
    </button>

    <!-- Floating Logs Panel -->
    <div
      v-if="isExpanded"
      class="mt-2 w-96 rounded-lg border border-slate-700 bg-slate-900/95 p-4 text-slate-200 backdrop-blur-lg"
    >
      <div class="mb-3 flex items-center justify-between border-b border-slate-800 pb-2">
        <div class="flex items-center gap-2">
          <span class="font-bold text-emerald-400">Live WebSocket Telemetry</span>
        </div>
        <div class="flex items-center gap-2">
          <button @click="clearLogs" class="text-slate-400 hover:text-white">Clear</button>
          <button @click="isExpanded = false" class="text-slate-400 hover:text-white">✕</button>
        </div>
      </div>

      <div v-if="logs.length === 0" class="py-6 text-center text-slate-500">
        No WebSocket events dispatched yet.
      </div>

      <div v-else class="max-h-64 space-y-1.5 overflow-y-auto pr-1">
        <div
          v-for="log in logs"
          :key="log.id"
          class="flex items-center justify-between rounded border border-slate-800 bg-slate-950/60 px-2.5 py-1.5"
        >
          <div class="flex items-center gap-2 overflow-hidden">
            <span
              :class="['h-2 w-2 rounded-full', log.ok ? 'bg-emerald-400' : 'bg-rose-500']"
            ></span>
            <span class="truncate text-slate-300">{{ log.event }}</span>
          </div>
          <div class="flex items-center gap-2 text-[11px]">
            <span class="text-slate-400">{{ log.timestamp }}</span>
            <span
              :class="[
                'rounded px-1 py-0.5 font-bold',
                log.durationMs < 50
                  ? 'bg-emerald-950 text-emerald-300'
                  : 'bg-amber-950 text-amber-300'
              ]"
            >
              {{ log.durationMs }}ms
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
