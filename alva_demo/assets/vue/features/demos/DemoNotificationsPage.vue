<script setup lang="ts">
import { ref, computed, watch } from "vue";
import { useAlva } from "../../../js/alva";
import type { AlvaSignals } from "../../../js/alva/signals";
import { Select, SelectContent, SelectGroup, SelectItem, SelectTrigger, SelectValue } from "@/vue/components/ui/select";

type NotificationSignal = AlvaSignals["demo_notifications.sent"]["payload"];

type ToastItem = {
  id: string;
  title: string;
  severity: "info" | "success" | "warning" | "danger";
  time: string;
};

const title = ref("Order #1042 fulfilled successfully.");
const severity = ref<"info" | "success" | "warning" | "danger">("success");
const sending = ref(false);
const error = ref<string | null>(null);
const activeFilter = ref<string>("all");
const toasts = ref<ToastItem[]>([]);

const alva = useAlva();

// Listen to PubSub signals live via generated composable
const { data: signalNotices } = alva.demo_notifications.use_sent_state();

watch(signalNotices, (newList) => {
  if (!newList || newList.length === 0) return;
  const latestItem = newList[0];
  const newToast: ToastItem = {
    id: Math.random().toString(36).substring(7),
    title: latestItem.title,
    severity: (latestItem.severity as any) || "info",
    time: new Date().toLocaleTimeString()
  };
  
  if (!toasts.value.some((t) => t.title === newToast.title && t.time === newToast.time)) {
    toasts.value.unshift(newToast);
    setTimeout(() => {
      dismissToast(newToast.id);
    }, 6000);
  }
}, { deep: true, immediate: true });

const dismissToast = (id: string) => {
  toasts.value = toasts.value.filter((t) => t.id !== id);
};

const sendNotification = async () => {
  const trimmedTitle = title.value.trim();
  if (!trimmedTitle || sending.value) return;

  sending.value = true;
  error.value = null;

  const result = await alva.demo_notifications.send({
    title: trimmedTitle,
    severity: severity.value as any,
  });

  sending.value = false;

  if (!result.ok) {
    error.value = result.error?.message || "Failed to publish the notification signal.";
  }
};

const filteredToasts = computed(() => {
  if (activeFilter.value === "all") return toasts.value;
  return toasts.value.filter((t) => t.severity === activeFilter.value);
});

const presetNotification = (presetTitle: string, presetSeverity: ToastItem["severity"]) => {
  title.value = presetTitle;
  severity.value = presetSeverity;
  sendNotification();
};
</script>

<template>
  <div class="max-w-5xl mx-auto py-12 px-6 lg:px-12 space-y-16" data-testid="demo-notifications-vue">
    <!-- Broadsheet Header -->
    <header class="space-y-6 pb-12 border-b border-[var(--color-rule)]">
      <div class="space-y-1">
        <span class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          № 03 — SIGNAL DISPATCH SPECIMEN
        </span>
        <p class="text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          Decoupled Semantic Notification Engine
        </p>
      </div>
      <h1 class="text-5xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display); line-height: 1.1;">
        Realtime Toast &amp; Notification Engine.
      </h1>
      <p class="text-lg text-[var(--color-ink-2)] max-w-[65ch]" style="line-height: 1.7;">
        Demonstrates decoupled Phoenix PubSub signals rendering live toast notifications without routing events through client-side state lists.
      </p>
    </header>

    <article class="grid grid-cols-1 md:grid-cols-[1fr_2fr] gap-12 lg:gap-16 items-start">
      <!-- Sidebar: Publish Form & Presets -->
      <aside class="space-y-8 pb-8 md:pb-0 border-b md:border-b-0 border-[var(--color-rule)] sticky top-8">
        <div class="space-y-1">
          <span class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
            PUBLISH SIGNAL
          </span>
          <h2 class="text-2xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">
            Fire Notification
          </h2>
        </div>

        <form class="space-y-6" @submit.prevent="sendNotification">
          <div class="space-y-2">
            <label class="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)]" for="demo-notification-title" style="font-family: var(--font-mono)">Notification Title</label>
            <input
              id="demo-notification-title"
              v-model="title"
              class="w-full rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 py-2 text-sm text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0 transition-colors font-mono"
              type="text"
            />
          </div>

          <div class="space-y-2">
            <label class="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)]" for="demo-notification-severity" style="font-family: var(--font-mono)">Severity Level</label>
            <Select v-model="severity">
              <SelectTrigger id="demo-notification-severity" class="w-full h-10 rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 focus:border-[var(--color-ink)] focus:ring-0 font-mono">
                <SelectValue placeholder="Select severity" />
              </SelectTrigger>
              <SelectContent class="rounded-none border border-[var(--color-rule)] bg-[var(--color-paper)] font-mono text-xs">
                <SelectGroup>
                  <SelectItem value="info">Info</SelectItem>
                  <SelectItem value="success">Success</SelectItem>
                  <SelectItem value="warning">Warning</SelectItem>
                  <SelectItem value="danger">Danger</SelectItem>
                </SelectGroup>
              </SelectContent>
            </Select>
          </div>

          <p v-if="error" class="text-xs text-red-600 font-mono">
            {{ error }}
          </p>

          <button
            class="btn--primary w-full py-4 text-xs font-semibold uppercase tracking-[0.1em] disabled:cursor-not-allowed disabled:opacity-50 transition-opacity"
            :disabled="sending || !title.trim()"
            type="submit"
          >
            {{ sending ? "Publishing..." : "Publish PubSub Signal" }}
          </button>
        </form>

        <!-- Quick Presets -->
        <div class="space-y-3 pt-4 border-t border-[var(--color-rule)]">
          <span class="text-xs font-mono font-semibold uppercase tracking-[0.1em] text-[var(--color-ink-2)] block">Quick Signal Presets:</span>
          <div class="flex flex-col gap-2">
            <button @click="presetNotification('Payment received ($149.00)', 'success')" class="text-left border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] p-2.5 text-xs font-mono hover:border-[var(--color-ink)] transition-colors">
              ✔ Success: Payment received ($149.00)
            </button>
            <button @click="presetNotification('Low inventory warning: Hoodies (2 units left)', 'warning')" class="text-left border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] p-2.5 text-xs font-mono hover:border-[var(--color-ink)] transition-colors">
              ⚠️ Warning: Low inventory warning
            </button>
            <button @click="presetNotification('System Database Backup Failed', 'danger')" class="text-left border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] p-2.5 text-xs font-mono hover:border-[var(--color-ink)] transition-colors">
              ❌ Danger: System Backup Failed
            </button>
          </div>
        </div>
      </aside>

      <!-- Main: Live Toast Queue & Log -->
      <section class="space-y-8">
        <div class="flex items-baseline justify-between border-b border-[var(--color-rule)] pb-4">
          <div class="space-y-1">
            <span class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
              REALTIME TOAST STACK
            </span>
            <h2 class="text-2xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display);">
              Active Signal Stream
            </h2>
          </div>

          <!-- Severity Filter Buttons -->
          <div class="flex items-center gap-2 font-mono text-xs">
            <button 
              v-for="f in ['all', 'success', 'warning', 'danger', 'info']" 
              :key="f"
              @click="activeFilter = f"
              class="uppercase tracking-[0.1em] py-1 px-2 border transition-colors"
              :class="activeFilter === f ? 'border-[var(--color-ink)] bg-[var(--color-paper-2)] text-[var(--color-ink)] font-bold' : 'border-transparent text-[var(--color-ink-2)] hover:text-[var(--color-ink)]'"
            >
              {{ f }}
            </button>
          </div>
        </div>

        <!-- Toast Notifications Queue -->
        <div class="space-y-4">
          <div 
            v-for="toast in filteredToasts" 
            :key="toast.id"
            class="border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-5 shadow-sm flex items-start justify-between gap-4 transition-all duration-300 animate-slide-in"
            :class="{
              'border-l-4 border-l-emerald-500': toast.severity === 'success',
              'border-l-4 border-l-amber-500': toast.severity === 'warning',
              'border-l-4 border-l-red-500': toast.severity === 'danger',
              'border-l-4 border-l-blue-500': toast.severity === 'info'
            }"
          >
            <div class="space-y-1">
              <div class="flex items-center gap-2">
                <span 
                  class="text-[10px] font-bold font-mono uppercase tracking-[0.1em] px-2 py-0.5 rounded"
                  :class="{
                    'bg-emerald-500/15 text-emerald-600': toast.severity === 'success',
                    'bg-amber-500/15 text-amber-600': toast.severity === 'warning',
                    'bg-red-500/15 text-red-600': toast.severity === 'danger',
                    'bg-blue-500/15 text-blue-600': toast.severity === 'info'
                  }"
                >
                  [{{ toast.severity }}]
                </span>
                <span class="text-[10px] font-mono text-[var(--color-ink-2)]">{{ toast.time }}</span>
              </div>
              <p class="text-base text-[var(--color-ink)] font-sans pt-1 leading-normal">{{ toast.title }}</p>
            </div>

            <button 
              @click="dismissToast(toast.id)"
              class="text-xs font-mono text-[var(--color-ink-2)] hover:text-[var(--color-ink)] px-2 py-1 border border-transparent hover:border-[var(--color-rule-2)]"
            >
              ✕ Dismiss
            </button>
          </div>

          <div v-if="filteredToasts.length === 0" class="text-sm text-[var(--color-ink-2)] italic py-12 text-center border border-dashed border-[var(--color-rule-2)]" style="font-family: var(--font-display);">
            No active toast signals. Click "Publish PubSub Signal" or use a preset to fire a signal.
          </div>
        </div>
      </section>
    </article>
  </div>
</template>
