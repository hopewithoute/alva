<script setup lang="ts">
import { computed, ref, watchPostEffect } from "vue";
import Button from "@/vue/shared/ui/button/Button.vue";
import { useAlva } from "@/js/alva";
import SpecimenSourceViewerModal from "@/vue/shared/components/SpecimenSourceViewerModal.vue";

const isSourceModalOpen = ref(false);
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
const limit = ref(15);
const chatContainerRef = ref<HTMLDivElement | null>(null);

// Dynamic reactive query for chat messages
const { data: queriedMessages, refetch } = alva.demo_chat.use_list_messages_query(
  () => ({ page: { limit: limit.value } }),
  { autoRefreshOnSignal: "demo_chat.message_sent" }
);

const messages = computed(() => {
  return queriedMessages.value?.length ? queriedMessages.value : (props.chat_messages ?? []);
});

watchPostEffect(() => {
  if (messages.value && chatContainerRef.value) {
    chatContainerRef.value.scrollTop = chatContainerRef.value.scrollHeight;
  }
});

const sendMessage = async () => {
  const trimmedAuthor = author.value.trim();
  const trimmedText = text.value.trim();

  if (!trimmedAuthor || !trimmedText || sending.value) return;

  sending.value = true;
  error.value = null;

  const result = await alva.demo_chat.send_message({
    author: trimmedAuthor,
    text: trimmedText
  });

  sending.value = false;

  if (result.ok) {
    text.value = "";
    await refetch();
  } else {
    error.value = result.error?.message || "Failed to send the demo message.";
  }
};
</script>

<template>
  <div class="w-full space-y-16 py-4" data-testid="demo-chat-vue">
    <!-- Broadsheet Header -->
    <header class="space-y-6 border-b border-[var(--color-rule)] pb-12">
      <div class="space-y-1">
        <span
          class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          № 01 — REALTIME STREAM SPECIMEN
        </span>
        <p
          class="text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          PubSub WebSocket Chat &amp; Infinite Feed
        </p>
      </div>
      <h1
        class="text-5xl font-normal text-[var(--color-ink)]"
        style="font-family: var(--font-display); line-height: 1.1"
      >
        Realtime Infinite Scroll Chat Stream.
      </h1>
      <div class="flex flex-col justify-between gap-6 sm:flex-row sm:items-end">
        <p class="max-w-[65ch] text-lg text-[var(--color-ink-2)]" style="line-height: 1.7">
          Demonstrates subscription-backed message broadcasting with automatic viewport scrolling,
          real-time message appends, and infinite historical pagination.
        </p>
        <Button variant="specimen" @click="isSourceModalOpen = true">
          <span>⚡ INSPECT SPECIMEN CODE</span>
        </Button>
      </div>
    </header>

    <article class="grid grid-cols-1 items-start gap-12 md:grid-cols-[1fr_2fr] lg:gap-16">
      <!-- Sidebar: Compose Form -->
      <aside
        class="sticky top-8 space-y-6 border-b border-[var(--color-rule)] pb-8 md:border-b-0 md:pb-0"
      >
        <div class="space-y-1">
          <span
            class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            COMPOSE MESSAGE
          </span>
          <h2
            class="text-2xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            Broadcast Stream
          </h2>
        </div>

        <form class="space-y-6" @submit.prevent="sendMessage">
          <div class="space-y-2">
            <label
              class="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)]"
              for="demo-chat-author"
              style="font-family: var(--font-mono)"
              >Author</label
            >
            <input
              id="demo-chat-author"
              v-model="author"
              type="text"
              class="w-full border border-[var(--color-rule-2)] bg-transparent p-3 text-sm text-[var(--color-ink)] outline-none transition-colors focus:border-[var(--color-ink)]"
              placeholder="Your name..."
              required
            />
          </div>

          <div class="space-y-2">
            <label
              class="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)]"
              for="demo-chat-text"
              style="font-family: var(--font-mono)"
              >Message</label
            >
            <textarea
              id="demo-chat-text"
              v-model="text"
              rows="3"
              class="w-full border border-[var(--color-rule-2)] bg-transparent p-3 text-sm text-[var(--color-ink)] outline-none transition-colors focus:border-[var(--color-ink)]"
              placeholder="Type your message..."
              required
            ></textarea>
          </div>

          <div v-if="error" class="font-mono text-xs text-red-500">
            {{ error }}
          </div>

          <button
            type="submit"
            class="btn--primary w-full py-3 text-xs font-semibold uppercase tracking-[0.1em]"
          >
            Broadcast Message &rarr;
          </button>
        </form>
      </aside>

      <!-- Main: Infinite Scroll Chat Viewport -->
      <section class="space-y-6">
        <div class="flex items-center justify-between border-b border-[var(--color-rule)] pb-4">
          <div class="space-y-1">
            <span
              class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]"
              style="font-family: var(--font-mono)"
            >
              STREAM OUTPUT
            </span>
            <h2
              class="text-2xl font-normal text-[var(--color-ink)]"
              style="font-family: var(--font-display)"
            >
              Message Log ({{ messages.length }})
            </h2>
          </div>
          <span class="animate-pulse font-mono text-xs text-[var(--color-accent)]"
            >● LIVE STREAM</span
          >
        </div>

        <!-- Chat Container Box -->
        <div class="space-y-6 border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-6">
          <!-- Message Scroll Area -->
          <div
            ref="chatContainerRef"
            class="max-h-[460px] space-y-6 overflow-y-auto scroll-smooth pr-2"
          >
            <div
              v-for="message in messages"
              :key="message.id"
              class="space-y-1 border-b border-[var(--color-rule)] pb-4 last:border-0"
            >
              <div class="flex items-center justify-between">
                <span
                  class="text-xs font-bold uppercase tracking-[0.1em] text-[var(--color-ink)]"
                  style="font-family: var(--font-mono)"
                >
                  {{ message.author }}
                </span>
                <span
                  v-if="message.created_at"
                  class="font-mono text-[10px] text-[var(--color-ink-2)]"
                >
                  {{ new Date(message.created_at).toLocaleTimeString() }}
                </span>
              </div>
              <p class="font-sans text-base leading-relaxed text-[var(--color-ink-2)]">
                {{ message.text }}
              </p>
            </div>

            <div
              v-if="messages.length === 0"
              class="py-8 text-center text-sm italic text-[var(--color-ink-2)]"
              style="font-family: var(--font-display)"
            >
              No messages broadcasted yet. Send one to start the stream.
            </div>
          </div>
        </div>
      </section>
    </article>

    <SpecimenSourceViewerModal v-model="isSourceModalOpen" specimen-id="chat" />
  </div>
</template>
