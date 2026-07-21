<script setup lang="ts">
import { computed, ref, watch, onMounted, nextTick } from "vue";
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
const limit = ref(15);
const chatContainerRef = ref<HTMLDivElement | null>(null);

// Dynamic reactive query for chat messages
const { data: queriedMessages, refetch } = alva.demo_chat.use_list_messages_query(
  () => ({ limit: limit.value }),
  { autoRefreshOnSignal: "demo_chat.message_sent" }
);

const messages = computed<ChatMessage[]>(() => {
  if (queriedMessages.value && queriedMessages.value.length > 0) {
    return queriedMessages.value;
  }
  return props.chat_messages ?? [];
});

const scrollToBottom = async () => {
  await nextTick();
  if (chatContainerRef.value) {
    chatContainerRef.value.scrollTop = chatContainerRef.value.scrollHeight;
  }
};

watch(messages, () => {
  scrollToBottom();
}, { immediate: true, deep: true });

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
    await refetch();
    scrollToBottom();
  } else {
    error.value = result.error?.message || "Failed to send the demo message.";
  }
};

const loadMoreOlderMessages = () => {
  limit.value += 10;
};
</script>

<template>
  <div class="max-w-5xl mx-auto py-12 px-6 lg:px-12 space-y-16" data-testid="demo-chat-vue">
    <!-- Broadsheet Header -->
    <header class="space-y-6 pb-12 border-b border-[var(--color-rule)]">
      <div class="space-y-1">
        <span class="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          № 01 — REALTIME STREAM SPECIMEN
        </span>
        <p class="text-[10px] uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          PubSub WebSocket Chat &amp; Infinite Feed
        </p>
      </div>
      <h1 class="text-5xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display); line-height: 1.1;">
        Realtime Infinite Scroll Chat Stream.
      </h1>
      <p class="text-lg text-[var(--color-ink-2)] max-w-[65ch]" style="line-height: 1.7;">
        Demonstrates subscription-backed message broadcasting with automatic viewport scrolling, real-time message appends, and infinite historical pagination.
      </p>
    </header>

    <article class="grid grid-cols-1 md:grid-cols-[1fr_2fr] gap-12 lg:gap-16 items-start">
      <!-- Sidebar: Compose Form -->
      <aside class="space-y-6 pb-8 md:pb-0 border-b md:border-b-0 border-[var(--color-rule)] sticky top-8">
        <div class="space-y-1">
          <span class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
            COMPOSE MESSAGE
          </span>
          <h2 class="text-2xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">
            Broadcast Stream
          </h2>
        </div>

        <form class="space-y-6" @submit.prevent="sendMessage">
          <div class="space-y-2">
            <label class="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)]" for="demo-chat-author" style="font-family: var(--font-mono)">Author</label>
            <input
              id="demo-chat-author"
              v-model="author"
              class="w-full rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 py-2 text-sm text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0 transition-colors font-mono"
              type="text"
            />
          </div>

          <div class="space-y-2">
            <label class="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)]" for="demo-chat-text" style="font-family: var(--font-mono)">Message</label>
            <textarea
              id="demo-chat-text"
              v-model="text"
              class="min-h-[120px] w-full rounded-none border border-[var(--color-rule-2)] bg-transparent p-3 text-sm text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0 transition-colors resize-y font-sans"
              placeholder="Type your broadcast message..."
            ></textarea>
          </div>

          <p v-if="error" class="text-xs text-red-600 font-mono">
            {{ error }}
          </p>

          <button
            class="btn--primary w-full py-4 text-xs font-semibold uppercase tracking-[0.1em] disabled:cursor-not-allowed disabled:opacity-50 transition-opacity"
            :disabled="sending || !author.trim() || !text.trim()"
            type="submit"
          >
            {{ sending ? "Broadcasting..." : "Broadcast Message" }}
          </button>
        </form>
      </aside>

      <!-- Main: Infinite Scroll Chat Viewport -->
      <section class="space-y-6">
        <div class="flex items-baseline justify-between border-b border-[var(--color-rule)] pb-4">
          <div class="space-y-1">
            <span class="text-xs font-semibold uppercase tracking-[0.15em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
              LIVE CHAT FEED
            </span>
            <h2 class="text-2xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display);">
              Message Viewport
            </h2>
          </div>
          <span class="text-xs font-mono text-[var(--color-ink-2)]">
            {{ messages.length }} message{{ messages.length === 1 ? '' : 's' }}
          </span>
        </div>

        <!-- Chat Container Box -->
        <div class="border border-[var(--color-rule-2)] bg-[var(--color-paper)] p-6 space-y-6">
          <!-- Load Older Messages Button -->
          <div class="text-center pb-4 border-b border-[var(--color-rule)]">
            <button 
              @click="loadMoreOlderMessages"
              class="border border-[var(--color-ink)] bg-transparent px-4 py-2 text-xs font-mono font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)] transition-colors hover:bg-[var(--color-ink)] hover:text-[var(--color-paper)]"
            >
              ↑ Load Older History (Limit: {{ limit }})
            </button>
          </div>

          <!-- Message Scroll Area -->
          <div 
            ref="chatContainerRef"
            class="max-h-[460px] overflow-y-auto space-y-6 pr-2 scroll-smooth"
          >
            <div
              v-for="message in messages"
              :key="message.id"
              class="space-y-1 border-b border-[var(--color-rule)] pb-4 last:border-0"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs font-bold uppercase tracking-[0.1em] text-[var(--color-ink)]" style="font-family: var(--font-mono)">
                  {{ message.author }}
                </span>
                <span v-if="message.created_at" class="text-[10px] font-mono text-[var(--color-ink-2)]">
                  {{ new Date(message.created_at).toLocaleTimeString() }}
                </span>
              </div>
              <p class="text-base text-[var(--color-ink-2)] leading-relaxed font-sans">{{ message.text }}</p>
            </div>
            
            <div v-if="messages.length === 0" class="text-sm text-[var(--color-ink-2)] italic py-8 text-center" style="font-family: var(--font-display);">
              No messages broadcasted yet. Send one to start the stream.
            </div>
          </div>
        </div>
      </section>
    </article>
  </div>
</template>
