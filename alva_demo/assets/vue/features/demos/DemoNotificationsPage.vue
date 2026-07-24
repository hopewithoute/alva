<script setup lang="ts">
import { ref, computed, watch } from "vue";
import Button from "@/vue/shared/ui/button/Button.vue";
import { useAlva } from "@/js/alva";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue
} from "@/vue/components/ui/select";
import SpecimenSourceViewerModal from "@/vue/shared/components/SpecimenSourceViewerModal.vue";

const isSourceModalOpen = ref(false);

export type NotificationSeverity = "info" | "success" | "warning" | "danger";

type ToastItem = {
  id: string;
  title: string;
  severity: NotificationSeverity;
  time: string;
};

const title = ref("Order #1042 fulfilled successfully.");
const severity = ref<NotificationSeverity>("success");
const sending = ref(false);
const error = ref();
const activeFilter = ref("all");
const toasts = ref<ToastItem[]>([]);

const alva = useAlva();

// Listen to PubSub signals live via generated composable
const { data: signalNotices } = alva.demo_notifications.use_sent_state();

const isValidSeverity = (val: unknown): val is ToastItem["severity"] => {
  return typeof val === "string" && ["info", "success", "warning", "danger"].includes(val);
};

const dismissToast = (id: string) => {
  toasts.value = toasts.value.filter((t) => t.id !== id);
};

const handleSignalNoticesChange = (newList: typeof signalNotices.value) => {
  if (!newList || newList.length === 0) return;
  const latestItem = newList[0];
  const newToast: ToastItem = {
    id: Math.random().toString(36).substring(7),
    title: latestItem.title,
    severity: isValidSeverity(latestItem.severity) ? latestItem.severity : "info",
    time: new Date().toLocaleTimeString()
  };

  if (!toasts.value.some((t) => t.title === newToast.title && t.time === newToast.time)) {
    toasts.value.unshift(newToast);
    setTimeout(() => {
      dismissToast(newToast.id);
    }, 6000);
  }
};

watch(signalNotices, handleSignalNoticesChange, { deep: true, immediate: true });

const sendNotification = async () => {
  const trimmedTitle = title.value.trim();
  if (!trimmedTitle || sending.value) return;

  sending.value = true;
  error.value = null;

  const result = await alva.demo_notifications.send({
    title: trimmedTitle,
    severity: severity.value
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
  <div class="w-full space-y-16 py-4" data-testid="demo-notifications-vue">
    <!-- Broadsheet Header -->
    <header class="space-y-6 border-b border-[var(--color-rule)] pb-12">
      <div class="space-y-1">
        <span
          class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          № 03 — SIGNAL DISPATCH SPECIMEN
        </span>
        <p
          class="text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          Decoupled Semantic Notification Engine
        </p>
      </div>
      <h1
        class="text-5xl font-normal text-[var(--color-ink)]"
        style="font-family: var(--font-display); line-height: 1.1"
      >
        Realtime Toast &amp; Notification Engine.
      </h1>
      <div class="flex flex-col justify-between gap-6 sm:flex-row sm:items-end">
        <p class="max-w-[65ch] text-lg text-[var(--color-ink-2)]" style="line-height: 1.7">
          Demonstrates decoupled Phoenix PubSub signals rendering live toast notifications without
          routing events through client-side state lists.
        </p>
        <Button variant="specimen" @click="isSourceModalOpen = true">
          <span>⚡ INSPECT SPECIMEN CODE</span>
        </Button>
      </div>
    </header>

    <article class="grid grid-cols-1 items-start gap-12 md:grid-cols-[1fr_2fr] lg:gap-16">
      <!-- Sidebar: Publish Form & Presets -->
      <aside
        class="sticky top-8 space-y-8 border-b border-[var(--color-rule)] pb-8 md:border-b-0 md:pb-0"
      >
        <div class="space-y-1">
          <span
            class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            PUBLISH SIGNAL
          </span>
          <h2
            class="text-2xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            Fire Notification
          </h2>
        </div>

        <form class="space-y-6" @submit.prevent="sendNotification">
          <div class="space-y-2">
            <label
              class="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)]"
              for="demo-notification-title"
              style="font-family: var(--font-mono)"
              >Notification Title</label
            >
            <input
              id="demo-notification-title"
              v-model="title"
              class="w-full rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 py-2 font-mono text-sm text-[var(--color-ink)] transition-colors focus:border-[var(--color-ink)] focus:outline-none focus:ring-0"
              type="text"
            />
          </div>

          <div class="space-y-2">
            <label
              class="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)]"
              for="demo-notification-severity"
              style="font-family: var(--font-mono)"
              >Severity Level</label
            >
            <Select v-model="severity">
              <SelectTrigger
                id="demo-notification-severity"
                class="h-10 w-full rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 font-mono focus:border-[var(--color-ink)] focus:ring-0"
              >
                <SelectValue placeholder="Select severity" />
              </SelectTrigger>
              <SelectContent
                class="rounded-none border border-[var(--color-rule)] bg-[var(--color-paper)] font-mono text-xs"
              >
                <SelectGroup>
                  <SelectItem value="info">Info</SelectItem>
                  <SelectItem value="success">Success</SelectItem>
                  <SelectItem value="warning">Warning</SelectItem>
                  <SelectItem value="danger">Danger</SelectItem>
                </SelectGroup>
              </SelectContent>
            </Select>
          </div>

          <p v-if="error" class="font-mono text-xs text-red-600">
            {{ error }}
          </p>

          <button
            class="btn--primary w-full py-4 text-xs font-semibold uppercase tracking-[0.1em] transition-opacity disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="sending || !title.trim()"
            type="submit"
          >
            {{ sending ? "Publishing..." : "Publish PubSub Signal" }}
          </button>
        </form>

        <!-- Quick Presets -->
        <div class="space-y-3 border-t border-[var(--color-rule)] pt-4">
          <span
            class="block font-mono text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
            >Quick Signal Presets:</span
          >
          <div class="flex flex-col gap-2">
            <button
              @click="presetNotification('Payment received ($149.00)', 'success')"
              class="border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] p-2.5 text-left font-mono text-xs transition-colors hover:border-[var(--color-ink)]"
            >
              ✔ Success: Payment received ($149.00)
            </button>
            <button
              @click="
                presetNotification('Low inventory warning: Hoodies (2 units left)', 'warning')
              "
              class="border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] p-2.5 text-left font-mono text-xs transition-colors hover:border-[var(--color-ink)]"
            >
              ⚠️ Warning: Low inventory warning
            </button>
            <button
              @click="presetNotification('System Database Backup Failed', 'danger')"
              class="border border-[var(--color-rule-2)] bg-[var(--color-paper-2)] p-2.5 text-left font-mono text-xs transition-colors hover:border-[var(--color-ink)]"
            >
              ❌ Danger: System Backup Failed
            </button>
          </div>
        </div>
      </aside>

      <!-- Main: Live Toast Queue & Log -->
      <section class="space-y-8">
        <div class="flex items-baseline justify-between border-b border-[var(--color-rule)] pb-4">
          <div class="space-y-1">
            <span
              class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
              style="font-family: var(--font-mono)"
            >
              REALTIME TOAST STACK
            </span>
            <h2
              class="text-2xl font-normal text-[var(--color-ink)]"
              style="font-family: var(--font-display)"
            >
              Active Signal Stream
            </h2>
          </div>

          <!-- Severity Filter Buttons -->
          <div class="flex items-center gap-2 font-mono text-xs">
            <button
              v-for="f in ['all', 'success', 'warning', 'danger', 'info']"
              :key="f"
              @click="activeFilter = f"
              class="border px-2 py-1 uppercase tracking-[0.1em] transition-colors"
              :class="
                activeFilter === f
                  ? 'border-[var(--color-ink)] bg-[var(--color-paper-2)] font-bold text-[var(--color-ink)]'
                  : 'border-transparent text-[var(--color-ink-2)] hover:text-[var(--color-ink)]'
              "
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
            class="animate-slide-in flex items-start justify-between gap-4 border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-5 shadow-sm transition-all duration-300"
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
                  class="rounded px-2 py-0.5 font-mono text-[10px] font-bold uppercase tracking-[0.1em]"
                  :class="{
                    'bg-emerald-500/15 text-emerald-600': toast.severity === 'success',
                    'bg-amber-500/15 text-amber-600': toast.severity === 'warning',
                    'bg-red-500/15 text-red-600': toast.severity === 'danger',
                    'bg-blue-500/15 text-blue-600': toast.severity === 'info'
                  }"
                >
                  [{{ toast.severity }}]
                </span>
                <span class="font-mono text-[10px] text-[var(--color-ink-2)]">{{
                  toast.time
                }}</span>
              </div>
              <p class="pt-1 font-sans text-base leading-normal text-[var(--color-ink)]">
                {{ toast.title }}
              </p>
            </div>

            <button
              @click="dismissToast(toast.id)"
              class="border border-transparent px-2 py-1 font-mono text-xs text-[var(--color-ink-2)] hover:border-[var(--color-rule-2)] hover:text-[var(--color-ink)]"
            >
              ✕ Dismiss
            </button>
          </div>

          <div
            v-if="filteredToasts.length === 0"
            class="border border-dashed border-[var(--color-rule-2)] py-12 text-center text-sm italic text-[var(--color-ink-2)]"
            style="font-family: var(--font-display)"
          >
            No active toast signals. Click "Publish PubSub Signal" or use a preset to fire a signal.
          </div>
        </div>
      </section>
    </article>
    <SpecimenSourceViewerModal v-model="isSourceModalOpen" specimen-id="notifications" />
  </div>
</template>
