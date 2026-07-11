<script setup lang="ts">
import { ref } from "vue";
import { useAlva } from "../../../js/alva";
import type { AlvaSignals } from "../../../js/alva/signals";
import { Select, SelectContent, SelectGroup, SelectItem, SelectTrigger, SelectValue } from "@/vue/components/ui/select";

type NotificationSignal = AlvaSignals["demo_notifications.sent"]["payload"];

const title = ref("Build finished cleanly.");
const severity = ref<NotificationSignal["severity"]>("success");
const sending = ref(false);
const error = ref<string | null>(null);
const notices = ref<NotificationSignal[]>([]);

const alva = useAlva();

alva.demo_notifications.on_sent({}, (payload) => {
  notices.value.unshift(payload);
});

const sendNotification = async () => {
  const trimmedTitle = title.value.trim();
  if (!trimmedTitle || sending.value) return;

  sending.value = true;
  error.value = null;

  const result = await alva.demo_notifications.send({
    title: trimmedTitle,
    severity: severity.value,
  });

  sending.value = false;

  if (!result.ok) {
    error.value = result.error?.message || "Failed to publish the notification.";
  }
};

const severityTone = (value: NotificationSignal["severity"]) => {
  if (value === "success") return "border-emerald-200 bg-emerald-50 text-emerald-700";
  if (value === "warning") return "border-amber-200 bg-amber-50 text-amber-700";
  return "border-sky-200 bg-sky-50 text-sky-700";
};
</script>

<template>
  <section class="space-y-6">
    <div class="max-w-3xl space-y-3">
      <p class="text-sm font-medium uppercase tracking-wide text-[var(--color-ink-2)]">Signals Demo</p>
      <h1 class="text-3xl font-semibold tracking-tight text-[var(--color-ink)]" style="font-family: var(--font-display);">Semantic notifications stay out of list state.</h1>
      <p class="text-sm text-[var(--color-ink-2)]">
        This route listens for a single signal and renders each payload like a toast log, without
        routing those occurrences through a collection or local list reconciliation path.
      </p>
    </div>

    <div class="grid gap-6 lg:grid-cols-[0.9fr_1.1fr]">
      <form class="space-y-4 rounded-xl border border-[var(--color-rule)] bg-[var(--color-paper)] p-5 shadow-sm" @submit.prevent="sendNotification">
        <div class="space-y-1">
          <label class="text-sm font-medium text-[var(--color-ink-2)]" for="demo-notification-title">Title</label>
          <input
            id="demo-notification-title"
            v-model="title"
            class="w-full rounded-md border border-[var(--color-rule)] px-3 py-2 text-sm"
            type="text"
          />
        </div>

        <div class="space-y-1">
          <label class="text-sm font-medium text-[var(--color-ink-2)]" for="demo-notification-severity">Severity</label>
          <Select v-model="severity">
            <SelectTrigger id="demo-notification-severity" class="w-full h-9 rounded-md border border-[var(--color-rule)] bg-[var(--color-paper)]">
              <SelectValue placeholder="Select severity" />
            </SelectTrigger>
            <SelectContent>
              <SelectGroup>
                <SelectItem value="info">Info</SelectItem>
                <SelectItem value="success">Success</SelectItem>
                <SelectItem value="warning">Warning</SelectItem>
              </SelectGroup>
            </SelectContent>
          </Select>
        </div>

        <p v-if="error" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {{ error }}
        </p>

        <button
          class="rounded-md bg-[var(--color-ink)] text-[var(--color-paper)] px-4 py-2 text-sm font-medium disabled:cursor-not-allowed disabled:opacity-60"
          :disabled="sending || !title.trim()"
          type="submit"
        >
          {{ sending ? "Sending..." : "Publish Signal" }}
        </button>
      </form>

      <div class="rounded-xl border border-[var(--color-rule)] bg-[var(--color-paper)] p-5 shadow-sm">
        <div class="mb-4 flex items-center justify-between">
          <h2 class="text-lg font-semibold text-[var(--color-ink)]" style="font-family: var(--font-display);">Signal Log</h2>
          <span class="rounded-full bg-[var(--color-rule)] px-2.5 py-1 text-xs font-medium text-[var(--color-ink-2)]">
            {{ notices.length }} received
          </span>
        </div>

        <div v-if="notices.length === 0" class="rounded-lg border border-dashed border-[var(--color-rule)] bg-[var(--color-rule)] px-4 py-5 text-sm text-[var(--color-ink-2)]">
          Publish a signal to see it appear here.
        </div>

        <div v-else class="space-y-3">
          <div
            v-for="notice in notices"
            :key="notice.id"
            :class="['rounded-lg border px-4 py-3', severityTone(notice.severity)]"
          >
            <div class="flex items-center justify-between gap-3">
              <p class="text-sm font-semibold">{{ notice.title }}</p>
              <span class="text-xs font-medium uppercase tracking-wide">{{ notice.severity }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
