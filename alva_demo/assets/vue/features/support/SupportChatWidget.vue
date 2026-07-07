<script setup lang="ts">
import { ref, watch, nextTick, computed } from "vue";
import { usePageEvent } from "alva";
import type { CustomerStorefrontLiveEvents } from "../../../js/alva/CustomerStorefrontLive.events";
import type { SupportMessage } from "../../../js/alva/types";
import { createAlvaApi } from "../../../js/alva/client";
import Button from "../../shared/ui/button/Button.vue";

const props = defineProps<{
  customerName: string;
  activeConversationId?: string | null;
  connectedCustomerName?: string | null;
  supportMessages?: SupportMessage[];
}>();

const emit = defineEmits<{
  (e: "join-chat"): void;
}>();

const api = createAlvaApi();
const joinChatEvent = usePageEvent<CustomerStorefrontLiveEvents, "support.join_chat">("support.join_chat");
const resetChatEvent = usePageEvent<CustomerStorefrontLiveEvents, "support.reset_chat">("support.reset_chat");

const newMessageText = ref("");
const isSendingMessage = ref(false);
const sendMessageError = ref<string | null>(null);
const chatMessagesEl = ref<HTMLElement | null>(null);

const isChatConnected = computed(() => {
  return Boolean(
    props.activeConversationId &&
    props.connectedCustomerName &&
    props.connectedCustomerName.toLowerCase() === props.customerName.toLowerCase()
  );
});

const chatStatus = computed(() => {
  if (!props.customerName) {
    return "Enter your customer name to unlock orders and support chat.";
  }
  if (joinChatEvent.isLoading.value) {
    return "Connecting your support conversation...";
  }
  if (isChatConnected.value) {
    return `Connected as ${props.connectedCustomerName}.`;
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
  if (!props.customerName || joinChatEvent.isLoading.value) return;
  if (isChatConnected.value) {
    await scrollChatToBottom();
    return;
  }

  const result = await joinChatEvent.call({
    customer_name: props.customerName,
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

  if (!props.activeConversationId) return;

  newMessageText.value = "";
  isSendingMessage.value = true;
  sendMessageError.value = null;

  try {
    const result = await api.call("support.send_message", {
      text: text,
      sender: "shopper",
      conversation_id: props.activeConversationId,
    });

    if (!result.ok) {
      sendMessageError.value = result.error?.message || "Failed to send message.";
      newMessageText.value = text;
    } else {
      await scrollChatToBottom();
    }
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

watch(() => props.supportMessages, async () => {
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

    <div ref="chatMessagesEl" class="flex-1 overflow-y-auto bg-zinc-50/40 px-5 py-4">
      <div v-if="joinChatEvent.error.value || sendMessageError" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
        {{ joinChatEvent.error.value?.message || sendMessageError }}
      </div>
      <div v-else-if="!customerName" class="rounded-lg border border-dashed border-zinc-200 bg-white px-4 py-5 text-sm text-zinc-500">
        Add your customer name on the left to unlock a dedicated support conversation.
      </div>
      <div v-else-if="!isChatConnected" class="rounded-lg border border-dashed border-zinc-200 bg-white px-4 py-5 text-sm text-zinc-500">
        Connect your support chat to load past messages and start a live thread with the merchant console.
      </div>
      <div v-else-if="!supportMessages?.length" class="rounded-lg border border-dashed border-zinc-200 bg-white px-4 py-5 text-sm text-zinc-500">
        Send a message to start the conversation.
      </div>
      
      <div v-if="isChatConnected && supportMessages?.length" class="flex flex-col justify-end space-y-4 min-h-full">
        <div
          v-for="message in supportMessages"
          :key="message.id"
          class="flex w-full"
          :class="message.sender === 'shopper' ? 'justify-end' : 'justify-start'"
        >
          <div
            class="max-w-[85%] rounded-2xl px-4 py-2 text-sm"
            :class="
              message.sender === 'shopper'
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
