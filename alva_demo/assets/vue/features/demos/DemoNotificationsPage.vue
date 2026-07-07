<script setup lang="ts">
import { ref } from "vue";
import { createAlvaApi } from "../../../js/alva/client";

type NotificationSignal = {
  id: string;
  title: string;
  severity: "info" | "success" | "warning";
  created_at?: string;
};

const api = createAlvaApi();
const title = ref("Build finished cleanly.");
const severity = ref<NotificationSignal["severity"]>("success");
const notices = ref<NotificationSignal[]>([]);
const error = ref<string | null>(null);
const sending = ref(false);

api.on("demo_notifications.sent", (payload: NotificationSignal) => {
  notices.value = [payload, ...notices.value].slice(0, 6);
});

const sendNotification = async () => {
  const trimmedTitle = title.value.trim();

  if (!trimmedTitle || sending.value) return;

  sending.value = true;
  error.value = null;

  const result = await api.call("demo_notifications.send", {
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
      <p class="text-sm font-medium uppercase tracking-wide text-zinc-500">Signals Demo</p>
      <h1 class="text-3xl font-semibold tracking-tight text-zinc-950">Semantic notifications stay out of list state.</h1>
      <p class="text-sm text-zinc-600">
        This route listens for a single signal and renders each payload like a toast log, without
        routing those occurrences through a collection or local list reconciliation path.
      </p>
    </div>

    <div class="grid gap-6 lg:grid-cols-[0.9fr_1.1fr]">
      <form class="space-y-4 rounded-xl border border-zinc-200 bg-white p-5 shadow-sm" @submit.prevent="sendNotification">
        <div class="space-y-1">
          <label class="text-sm font-medium text-zinc-700" for="demo-notification-title">Title</label>
          <input
            id="demo-notification-title"
            v-model="title"
            class="w-full rounded-md border border-zinc-300 px-3 py-2 text-sm"
            type="text"
          />
        </div>

        <div class="space-y-1">
          <label class="text-sm font-medium text-zinc-700" for="demo-notification-severity">Severity</label>
          <select
            id="demo-notification-severity"
            v-model="severity"
            class="w-full rounded-md border border-zinc-300 px-3 py-2 text-sm"
          >
            <option value="info">Info</option>
            <option value="success">Success</option>
            <option value="warning">Warning</option>
          </select>
        </div>

        <p v-if="error" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {{ error }}
        </p>

        <button
          class="rounded-md bg-zinc-950 px-4 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-60"
          :disabled="sending || !title.trim()"
          type="submit"
        >
          {{ sending ? "Sending..." : "Publish Signal" }}
        </button>
      </form>

      <div class="rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
        <div class="mb-4 flex items-center justify-between">
          <h2 class="text-lg font-semibold text-zinc-950">Signal Log</h2>
          <span class="rounded-full bg-zinc-100 px-2.5 py-1 text-xs font-medium text-zinc-600">
            {{ notices.length }} received
          </span>
        </div>

        <div v-if="notices.length === 0" class="rounded-lg border border-dashed border-zinc-200 bg-zinc-50 px-4 py-5 text-sm text-zinc-500">
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
