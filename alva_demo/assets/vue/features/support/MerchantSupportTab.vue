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
  <section class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
    <div class="flex flex-col gap-6 xl:flex-row xl:items-end xl:justify-between border-b border-zinc-200 pb-5">
      <div class="flex items-center gap-3">
        <h2 class="text-lg font-semibold text-zinc-900">Support Chat</h2>
        <span class="inline-flex items-center rounded-full bg-zinc-100 px-2.5 py-1 text-zinc-700">
          {{ props.conversations?.length || 0 }} threads
        </span>
      </div>

      <div class="flex flex-col gap-3 xl:flex-row xl:items-end">
        <label class="flex min-w-[260px] flex-col gap-2 text-sm font-medium text-zinc-700">
          <input
            v-model="conversation_filters.customer"
            data-testid="merchant-conversation-query"
            type="text"
            placeholder="Search customer name"
            class="h-9 rounded-md border border-zinc-300 px-3 text-sm font-normal text-zinc-950"
          />
        </label>

        <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
          <label class="inline-flex items-center gap-2 text-sm font-medium text-zinc-700">
            <input v-model="conversation_filters.waiting" type="checkbox" class="h-4 w-4 rounded border-zinc-300" />
            Waiting on merchant only
          </label>
          <Button variant="secondary" size="sm" :disabled="!isConversationFiltered" @click="clearConversationFilters">
            Reset
          </Button>
        </div>
      </div>
    </div>

    <div class="mt-6 flex h-[560px] overflow-hidden rounded-lg border border-zinc-200">
      <div class="w-[320px] overflow-y-auto border-r border-zinc-200 bg-zinc-50">
        <div v-if="!props.conversations?.length" class="p-4 text-sm text-zinc-500">
          No conversations match the current query.
        </div>
        <div v-else>
          <button
            v-for="conversation in props.conversations || []"
            :key="conversation.id"
            :data-testid="`merchant-conversation-${conversation.id}`"
            type="button"
            class="w-full border-b border-zinc-200 p-4 text-left transition-colors hover:bg-zinc-100"
            :class="props.activeConversationId === conversation.id ? 'bg-zinc-100' : ''"
            @click="selectConversation(conversation.id)"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="font-medium text-zinc-900">{{ conversation.customer_name }}</p>
                <p class="mt-1 truncate text-xs text-zinc-500">{{ conversation.last_message_preview || "No messages yet." }}</p>
              </div>
              <div class="flex flex-col items-end gap-1">
                <span v-if="conversation.needs_merchant_reply" class="inline-flex items-center rounded-full bg-red-100 px-2 py-0.5 text-[11px] font-medium text-red-700">
                  Waiting
                </span>
                <span class="inline-flex min-w-[2rem] items-center justify-center rounded-full bg-white px-2 py-0.5 text-[11px] font-medium text-zinc-600">
                  {{ conversation.message_count || 0 }}
                </span>
              </div>
            </div>
            <p class="mt-2 text-[11px] uppercase tracking-wide text-zinc-400">
              {{ formatDateTime(conversation.last_message_at) }}
            </p>
          </button>
        </div>
      </div>

      <div class="flex min-w-0 flex-1 flex-col bg-white">
        <div v-if="!active_conversation" class="flex flex-1 items-center justify-center text-sm text-zinc-500">
          Select a conversation to reply.
        </div>
        <template v-else>
          <div class="border-b border-zinc-200 bg-white p-4">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h3 class="font-medium text-zinc-950">Chatting with {{ active_conversation.customer_name }}</h3>
                <p class="mt-1 text-xs text-zinc-500">{{ formatDateTime(active_conversation.last_message_at) }}</p>
              </div>
              <div class="flex items-center gap-2">
                <span v-if="active_conversation.needs_merchant_reply" class="inline-flex items-center rounded-full bg-red-100 px-2.5 py-1 text-xs font-medium text-red-700">
                  Waiting on merchant
                </span>
                <span v-else class="inline-flex items-center rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-medium text-emerald-700">
                  Merchant replied
                </span>
              </div>
            </div>
          </div>

          <div ref="chat_messages_el" class="flex-1 space-y-3 overflow-y-auto bg-zinc-50/30 p-4">
            <div v-if="send_reply_error" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
              {{ send_reply_error }}
            </div>
            <div v-if="isSelectingConversation" class="rounded-lg border border-dashed border-zinc-200 bg-white px-4 py-5 text-sm text-zinc-500">
              Loading messages...
            </div>
            <div v-else-if="props.supportMessages?.length === 0" class="mt-4 text-center text-sm text-zinc-500">
              No messages yet.
            </div>
            <div v-for="msg in props.supportMessages" :key="msg.id" :class="['flex', msg.sender === 'merchant' ? 'justify-end' : 'justify-start']">
              <div :class="['max-w-[80%] rounded-lg px-3 py-2 text-sm', msg.sender === 'merchant' ? 'bg-blue-600 text-white' : 'border border-zinc-200 bg-white text-zinc-900']">
                {{ msg.text }}
              </div>
            </div>
          </div>

          <div class="flex gap-2 border-t border-zinc-200 bg-white p-3">
            <input v-model="new_message_text" data-testid="merchant-reply-input" @keyup.enter="sendReply" type="text" placeholder="Type a reply..." class="flex-1 rounded-md border border-zinc-300 px-3 py-1.5 text-sm" />
            <Button size="sm" @click="sendReply" :disabled="!new_message_text.trim() || is_sending_reply">
              <span class="inline-block min-w-[52px] text-center">{{ is_sending_reply ? "Sending..." : "Send" }}</span>
            </Button>
          </div>
        </template>
      </div>
    </div>
  </section>
</template>
