<script setup lang="ts">
import { computed, ref } from "vue";
import { useAlva } from "../../../js/alva";

const alva = useAlva();

type ChatMessage = {
  id: string;
  author: string;
  text: string;
  created_at?: string;
};

const props = defineProps<{
  chat_messages?: ChatMessage[];
}>();


const author = ref("Developer");
const text = ref("");
const error = ref<string | null>(null);
const sending = ref(false);

const messages = computed(() => props.chat_messages ?? []);

const sendMessage = async () => {
  const trimmedAuthor = author.value.trim();
  const trimmedText = text.value.trim();

  if (!trimmedAuthor || !trimmedText || sending.value) return;

  sending.value = true;
  error.value = null;

  const result = await alva.demo_chat.send_message({
    author: trimmedAuthor,
    text: trimmedText,
  });

  sending.value = false;

  if (result.ok) {
    text.value = "";
  } else {
    error.value = result.error?.message || "Failed to send the demo message.";
  }
};
</script>

<template>
  <section class="space-y-6">
    <div class="max-w-3xl space-y-3">
      <p class="text-sm font-medium uppercase tracking-wide text-[var(--color-ink-2)]">Stream Demo</p>
      <h1 class="text-3xl font-semibold tracking-tight text-[var(--color-ink)]" style="font-family: var(--font-display);">Chat messages append in realtime.</h1>
      <p class="text-sm text-[var(--color-ink-2)]">
        This page keeps one subscription-backed stream pattern in view:
        commands create chat messages, and the server-owned stream appends
        those messages across every open page.
      </p>
    </div>

    <div class="grid gap-6 lg:grid-cols-[0.9fr_1.1fr]">
      <form class="space-y-4 rounded-xl border border-[var(--color-rule)] bg-[var(--color-paper)] p-5 shadow-sm" @submit.prevent="sendMessage">
        <div class="space-y-1">
          <label class="text-sm font-medium text-[var(--color-ink-2)]" for="demo-chat-author">Author</label>
          <input
            id="demo-chat-author"
            v-model="author"
            class="w-full rounded-md border border-[var(--color-rule)] px-3 py-2 text-sm"
            type="text"
          />
        </div>

        <div class="space-y-1">
          <label class="text-sm font-medium text-[var(--color-ink-2)]" for="demo-chat-text">Message</label>
          <textarea
            id="demo-chat-text"
            v-model="text"
            class="min-h-[120px] w-full rounded-md border border-[var(--color-rule)] px-3 py-2 text-sm"
            placeholder="Send a line and watch the stream append it."
          ></textarea>
        </div>

        <p v-if="error" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {{ error }}
        </p>

        <button
          class="rounded-md bg-[var(--color-ink)] text-[var(--color-paper)] px-4 py-2 text-sm font-medium disabled:cursor-not-allowed disabled:opacity-60"
          :disabled="sending || !author.trim() || !text.trim()"
          type="submit"
        >
          {{ sending ? "Sending..." : "Send Message" }}
        </button>
      </form>

      <div class="rounded-xl border border-[var(--color-rule)] bg-[var(--color-paper)] p-5 shadow-sm">
        <div class="mb-4 flex items-center justify-between">
          <h2 class="text-lg font-semibold text-[var(--color-ink)]" style="font-family: var(--font-display);">Live Stream</h2>
          <span class="rounded-full bg-[var(--color-rule)] px-2.5 py-1 text-xs font-medium text-[var(--color-ink-2)]">
            {{ messages.length }} messages
          </span>
        </div>

        <div class="space-y-3">
          <div
            v-for="message in messages"
            :key="message.id"
            class="rounded-lg border border-[var(--color-rule)] bg-[var(--color-rule)] px-4 py-3"
          >
            <p class="text-sm font-semibold text-[var(--color-ink)]">{{ message.author }}</p>
            <p class="mt-1 text-sm text-[var(--color-ink-2)]">{{ message.text }}</p>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
