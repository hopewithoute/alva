<script setup lang="ts">
import { ref, nextTick, computed } from "vue";
import { usePageEvent, usePageState } from "alva";
import type { CustomerStorefrontLiveEvents } from "../../../js/alva/CustomerStorefrontLive.events";
import type { SupportMessage } from "../../../js/alva/types";
import { createAlvaApi } from "../../../js/alva/client";
import Button from "../../shared/ui/button/Button.vue";

const emit = defineEmits<{
  (e: "join-chat"): void;
}>();

const { connected_customer_name, active_conversation_id, support_messages } = usePageState<{
  connected_customer_name: string | null;
  active_conversation_id: string | null;
  support_messages: SupportMessage[];
}>();

const api = createAlvaApi();
const joinChatEvent = usePageEvent<CustomerStorefrontLiveEvents, "support.join_chat">("support.join_chat");
const resetChatEvent = usePageEvent<CustomerStorefrontLiveEvents, "support.reset_chat">("support.reset_chat");

const newMessageText = ref("");
const isSendingMessage = ref(false);
const sendMessageError = ref<string | null>(null);
const chatMessagesEl = ref<HTMLElement | null>(null);

const isChatConnected = computed(() => {
  return Boolean(active_conversation_id?.value && connected_customer_name?.value);
});

const chatStatus = computed(() => {
  if (!connected_customer_name?.value) {
    return "Enter your customer name to unlock orders and support chat.";
  }
  if (joinChatEvent.isLoading.value) {
    return "Connecting your support conversation...";
  }
  if (isChatConnected.value) {
    return `Connected as ${connected_customer_name.value}.`;
  }
  return "Connect once, then keep chatting with merchant support here.";
});

const scrollChatToBottom = async () => {
  await nextTick();
  if (chatMessagesEl.value) {
    chatMessagesEl.value.scrollTop = chatMessagesEl.value.scrollHeight;
  }
};

const joinChat = async () => {
  if (!connected_customer_name?.value || joinChatEvent.isLoading.value) return;
  if (isChatConnected.value) {
    await scrollChatToBottom();
    return;
  }

  const result = await joinChatEvent.call({
    customer_name: connected_customer_name.value,
  });

  if (result && result.ok) {
    emit("join-chat");
    await scrollChatToBottom();
  }
};

const sendMessage = async () => {
  const text = newMessageText.value.trim();
  if (!text || isSendingMessage.value) return;

  if (!isChatConnected.value) {
    await joinChat();
  }

  if (!active_conversation_id?.value) return;

  newMessageText.value = "";
  isSendingMessage.value = true;
  sendMessageError.value = null;

  try {
    const result = await api.call("support.send_message", {
      text: text,
      sender: "shopper",
      conversation_id: active_conversation_id.value,
    });

    if (!result.ok) {
      sendMessageError.value = result.error?.message || "Failed to send message.";
      newMessageText.value = text;
    } else {
      await scrollChatToBottom();
    }
  } catch (err: any) {
    sendMessageError.value = err.message || "Failed to send message.";
    newMessageText.value = text;
  } finally {
    isSendingMessage.value = false;
  }
};

const resetChatState = async () => {
  if (resetChatEvent.isLoading.value) return;
  newMessageText.value = "";
  isSendingMessage.value = false;
  sendMessageError.value = null;
  await resetChatEvent.call({});
};

watch(support_messages, async () => {
  await scrollChatToBottom();
}, { deep: true });

watch(() => props.customerName, (next, prev) => {
  if (props.connectedCustomerName && next !== props.connectedCustomerName) {
    void resetChatState();
  }
});
</script>

<template>
  <div class="flex h-full min-h-[620px] flex-col rounded-xl border border-zinc-200 bg-white shadow-sm xl:sticky xl:top-24">
    <div class="border-b border-zinc-200 px-5 py-4">
      <div class="flex items-start justify-between gap-3">
        <div>
          <p class="text-sm font-medium text-zinc-900">Support Chat</p>
          <p class="mt-1 text-sm text-zinc-500">{{ chatStatus }}</p>
        </div>
        <span class="rounded-full border border-zinc-200 bg-zinc-50 px-2.5 py-1 text-[11px] font-medium uppercase tracking-wide text-zinc-500">
          {{ isChatConnected ? "live" : "standby" }}
        </span>
      </div>
    </div>

    <div class="flex-1 overflow-y-auto bg-zinc-50/40">
      <div v-if="joinChatEvent.error.value || sendMessageError" class="m-5 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
        {{ joinChatEvent.error.value?.message || sendMessageError }}
      </div>
      <div v-if="!isChatConnected" class="flex h-[360px] flex-col items-center justify-center p-8 text-center text-sm text-zinc-500">
        <div class="mb-4 rounded-full bg-zinc-100 p-3">
          <svg class="h-6 w-6 text-zinc-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
          </svg>
        </div>
        <p>{{ chatStatus }}</p>
        <Button
          v-if="connected_customer_name"
          variant="secondary"
          size="sm"
          class="mt-4"
          @click="joinChat"
          :disabled="joinChatEvent.isLoading.value"
        >
          {{ joinChatEvent.isLoading.value ? "Connecting..." : "Start Chat" }}
        </Button>
      </div>

      <div v-else ref="chatMessagesEl" class="h-[360px] space-y-4 overflow-y-auto p-4">
        <div v-if="!support_messages?.length" class="flex h-full flex-col items-center justify-center text-sm text-zinc-500">
          <p>You're connected!</p>
          <p class="mt-1">Send a message to start the conversation.</p>
        </div>
        
        <div
          v-for="msg in support_messages"
          :key="msg.id"
          class="flex"
          :class="msg.sender === 'shopper' ? 'justify-end' : 'justify-start'"
        >
          <div
            class="max-w-[85%] rounded-2xl px-4 py-2 text-sm"
            :class="
              msg.sender === 'shopper'
                ? 'bg-zinc-900 text-white rounded-br-sm'
                : 'bg-white border border-zinc-200 text-zinc-900 shadow-sm rounded-bl-sm'
            "
          >
            {{ message.text }}
          </div>
        </div>
      </div>
    </div>

    <div class="border-t border-zinc-200 bg-white p-4">
      <div class="flex gap-2">
        <input
          v-model="newMessageText"
          type="text"
          placeholder="Type a message..."
          class="flex-1 rounded-md border border-zinc-300 px-3 text-sm font-normal text-zinc-950 disabled:cursor-not-allowed disabled:bg-zinc-50 disabled:text-zinc-500"
          :disabled="!customerName"
          @keyup.enter="sendMessage"
        />
        <Button
          variant="primary"
          @click="sendMessage"
          :disabled="!newMessageText.trim() || isSendingMessage || !customerName"
        >
          {{ isSendingMessage ? "Sending..." : "Send" }}
        </Button>
      </div>
    </div>
  </div>
</template>
