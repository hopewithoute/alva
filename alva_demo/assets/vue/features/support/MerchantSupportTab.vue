<script setup lang="ts">
import { ref, reactive, watch, computed, nextTick } from "vue";
import { useAlva } from "../../../js/alva";
import type { Conversation, SupportMessage } from "../../../js/alva/types";
import type { ConversationFilters } from "../merchant/types";
import Button from "../../shared/ui/button/Button.vue";
import { useDebounce } from "../../utils/debounce";
import { useRouteQueryPatch } from "../../shared/useRouteQueryPatch";

const alva = useAlva();

const props = defineProps<{
  conversations?: Conversation[];
  activeConversationId?: string | null;
  supportMessages?: SupportMessage[];
  isConversationFiltered?: boolean;
  initialFilters?: ConversationFilters;
}>();

const { patchQuery } = useRouteQueryPatch();
const isSelectingConversation = ref(false);

const conversation_filters = reactive<ConversationFilters>({
  customer: props.initialFilters?.customer || "",
  waiting: props.initialFilters?.waiting || false,
});

watch(
  () => props.initialFilters,
  (newVal) => {
    if (!newVal) return;
    conversation_filters.customer = newVal.customer || "";
    conversation_filters.waiting = newVal.waiting || false;
  },
  { deep: true, immediate: true }
);

const new_message_text = ref("");
const is_sending_reply = ref(false);
const send_reply_error = ref<string | null>(null);
const chat_messages_el = ref<HTMLElement | null>(null);

watch(
  conversation_filters,
  useDebounce((filters: ConversationFilters) => {
    patchQuery({
      conv_customer: filters.customer || null,
      conv_waiting: filters.waiting ? "true" : null,
    });
  }, 300),
  { deep: true },
);

const clearConversationFilters = () => {
  conversation_filters.customer = "";
  conversation_filters.waiting = false;
};

const active_conversation = computed(() => {
  if (!props.activeConversationId) return null;
  return (
    props.conversations?.find((c) => c.id === props.activeConversationId) ??
    null
  );
});

const formatDateTime = (value?: string | null) => {
  if (!value) return "No activity yet";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "No activity yet";
  return date.toLocaleString(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
};

const selectConversation = async (conversation_id: string) => {
  if (conversation_id === props.activeConversationId) {
    return;
  }

  isSelectingConversation.value = true;
  patchQuery(
    { conversation_id },
    { replace: false },
  );
};

const sendReply = async () => {
  const text = new_message_text.value.trim();
  if (!text || !props.activeConversationId || is_sending_reply.value) return;

  new_message_text.value = "";
  is_sending_reply.value = true;
  send_reply_error.value = null;

  try {
    const result = await alva.support.send_message({
      text: text,
      sender: "merchant",
      conversation_id: props.activeConversationId,
    });
    if (!result.ok) {
      send_reply_error.value = result.error?.message || "Failed to send reply.";
      new_message_text.value = text;
    }
  } finally {
    is_sending_reply.value = false;
  }
};

watch(
  () => props.supportMessages,
  async () => {
    await nextTick();
    if (chat_messages_el.value) {
      chat_messages_el.value.scrollTop = chat_messages_el.value.scrollHeight;
    }
  },
);

watch(
  () => props.activeConversationId,
  () => {
    isSelectingConversation.value = false;
  }
);
</script>

<template>
  <section class="space-y-8">
    <div class="flex flex-col gap-6 border-b border-[var(--color-rule)] pb-6 md:flex-row md:items-end md:justify-between">
      <div class="flex items-baseline gap-4">
        <h2 class="text-2xl font-normal text-[var(--color-ink)]" style="font-family: var(--font-display);">Support Chat</h2>
        <span class="text-xs text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          {{ props.conversations?.length || 0 }} threads
        </span>
      </div>

      <div class="flex flex-col gap-4 sm:flex-row sm:items-end">
        <input
          v-model="conversation_filters.customer"
          data-testid="merchant-conversation-query"
          type="text"
          placeholder="Search customer..."
          class="h-8 w-48 rounded-none border-0 border-b border-[var(--color-rule-2)] px-0 text-sm font-normal text-[var(--color-ink)] bg-transparent focus:border-[var(--color-ink)] focus:outline-none focus:ring-0"
        />

        <label class="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink-2)] cursor-pointer" style="font-family: var(--font-mono)">
          <input v-model="conversation_filters.waiting" type="checkbox" class="h-3.5 w-3.5 rounded-none border-[var(--color-rule)] text-[var(--color-ink)] focus:ring-0" />
          Waiting only
        </label>

        <Button variant="secondary" size="sm" class="rounded-none text-xs font-mono uppercase tracking-[0.1em]" :disabled="!isConversationFiltered" @click="clearConversationFilters">
          Reset
        </Button>
      </div>
    </div>

    <div class="mt-6 flex h-[560px] overflow-hidden border border-[var(--color-rule)]">
      <div class="w-[320px] overflow-y-auto border-r border-[var(--color-rule)] bg-[var(--color-paper-2)]">
        <div v-if="!props.conversations?.length" class="p-4 text-sm text-[var(--color-ink-2)] italic" style="font-family: var(--font-display)">
          No conversations match the current query.
        </div>
        <div v-else>
          <button
            v-for="conversation in props.conversations || []"
            :key="conversation.id"
            :data-testid="`merchant-conversation-${conversation.id}`"
            type="button"
            class="w-full border-b border-[var(--color-rule)] p-4 text-left transition-colors hover:bg-[var(--color-paper)]"
            :class="props.activeConversationId === conversation.id ? 'bg-[var(--color-paper)] border-l-2 border-l-[var(--color-ink)]' : ''"
            @click="selectConversation(conversation.id)"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="font-normal text-[var(--color-ink)]" style="font-family: var(--font-display)">{{ conversation.customer_name }}</p>
                <p class="mt-1 truncate text-xs text-[var(--color-ink-2)]">{{ conversation.last_message_preview || "No messages yet." }}</p>
              </div>
              <div class="flex flex-col items-end gap-1">
                <span v-if="conversation.needs_merchant_reply" class="border border-danger-border bg-danger-surface px-1.5 py-0.5 text-[9px] font-semibold uppercase tracking-[0.1em] text-danger" style="font-family: var(--font-mono)">
                  Waiting
                </span>
                <span class="text-[10px] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
                  {{ conversation.message_count || 0 }} msgs
                </span>
              </div>
            </div>
            <p class="mt-2 text-[10px] uppercase tracking-[0.1em] text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
              {{ formatDateTime(conversation.last_message_at) }}
            </p>
          </button>
        </div>
      </div>

      <div class="flex min-w-0 flex-1 flex-col bg-[var(--color-paper)]">
        <div v-if="!active_conversation" class="flex flex-1 items-center justify-center text-sm text-[var(--color-ink-2)] italic" style="font-family: var(--font-display)">
          Select a conversation to reply.
        </div>
        <template v-else>
          <div class="border-b border-[var(--color-rule)] p-4">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h3 class="font-normal text-[var(--color-ink)]" style="font-family: var(--font-display);">Chatting with {{ active_conversation.customer_name }}</h3>
                <p class="mt-1 text-xs text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">{{ formatDateTime(active_conversation.last_message_at) }}</p>
              </div>
              <div class="flex items-center gap-2">
                <span v-if="active_conversation.needs_merchant_reply" class="border border-danger-border bg-danger-surface px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.1em] text-danger" style="font-family: var(--font-mono)">
                  Waiting on merchant
                </span>
                <span v-else class="border border-success-border bg-success-surface px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.1em] text-success" style="font-family: var(--font-mono)">
                  Merchant replied
                </span>
              </div>
            </div>
          </div>

          <div ref="chat_messages_el" class="flex-1 space-y-4 overflow-y-auto p-4">
            <div v-if="send_reply_error" class="border border-danger-border bg-danger-surface p-3 text-sm text-danger italic" style="font-family: var(--font-display)">
              {{ send_reply_error }}
            </div>
            <div v-if="isSelectingConversation" class="border border-dashed border-[var(--color-rule)] p-4 text-sm text-[var(--color-ink-2)] italic" style="font-family: var(--font-display)">
              Loading messages...
            </div>
            <div v-else-if="props.supportMessages?.length === 0" class="mt-4 text-center text-sm text-[var(--color-ink-2)] italic" style="font-family: var(--font-display)">
              No messages yet.
            </div>
            <div v-for="msg in props.supportMessages" :key="msg.id" :class="['flex', msg.sender === 'merchant' ? 'justify-end' : 'justify-start']">
              <div :class="['max-w-[80%] px-4 py-2 text-sm', msg.sender === 'merchant' ? 'bg-[var(--color-accent)] text-[var(--color-accent-ink)]' : 'border border-[var(--color-rule)] bg-[var(--color-paper-2)] text-[var(--color-ink)]']">
                {{ msg.text }}
              </div>
            </div>
          </div>

          <div class="flex gap-4 border-t border-[var(--color-rule)] p-3">
            <input v-model="new_message_text" data-testid="merchant-reply-input" @keyup.enter="sendReply" type="text" placeholder="Type a reply..." class="flex-1 rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 text-sm text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0" />
            <Button size="sm" class="btn--primary px-6 text-xs" @click="sendReply" :disabled="!new_message_text.trim() || is_sending_reply">
              <span class="inline-block min-w-[52px] text-center">{{ is_sending_reply ? "Sending..." : "Send" }}</span>
            </Button>
          </div>
        </template>
      </div>
    </div>
  </section>
</template>
