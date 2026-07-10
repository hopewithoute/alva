<script setup lang="ts">
import { ref, nextTick, computed, watch } from "vue";
import type { SupportMessage } from "../../../js/alva/types";
import { useAlva } from "../../../js/alva";
import Button from "../../shared/ui/button/Button.vue";
import { useRouteQueryPatch } from "../../shared/useRouteQueryPatch";

const alva = useAlva();

const props = defineProps<{
  connectedCustomerName?: string | null;
  activeConversationId?: string | null;
  supportMessages?: SupportMessage[];
}>();

const newMessageText = ref("");
const isSendingMessage = ref(false);
const isJoiningChat = ref(false);
const joinChatError = ref<string | null>(null);
const sendMessageError = ref<string | null>(null);
const chatMessagesEl = ref<HTMLElement | null>(null);
const { patchQuery } = useRouteQueryPatch();

const isChatConnected = computed(() => {
  return Boolean(props.activeConversationId && props.connectedCustomerName);
});

const chatStatus = computed(() => {
  if (!props.connectedCustomerName) {
    return "Enter your customer name to unlock orders and support chat.";
  }
  if (isJoiningChat.value) {
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
  if (!props.connectedCustomerName || isJoiningChat.value) {
    return props.activeConversationId || null;
  }

  if (isChatConnected.value) {
    await scrollChatToBottom();
    return props.activeConversationId || null;
  }

  isJoiningChat.value = true;
  joinChatError.value = null;

  try {
    const result = await alva.support.create({
      customer_name: props.connectedCustomerName,
    });

    if (!result.ok) {
      joinChatError.value = result.error?.message || "Failed to create support conversation.";
      return null;
    }

    const conversationId = result.data?.id || null;

    patchQuery(
      {
        customer_name: props.connectedCustomerName,
        conversation_id: conversationId,
      },
      { replace: false },
    );

    await scrollChatToBottom();
    return conversationId;
  } catch (error: any) {
    joinChatError.value = error.message || "Failed to create support conversation.";
    return null;
  } finally {
    isJoiningChat.value = false;
  }
};

const sendMessage = async () => {
  const text = newMessageText.value.trim();
  if (!text || isSendingMessage.value) return;

  let conversationId = props.activeConversationId || null;

  if (!isChatConnected.value) {
    conversationId = await joinChat();
  }

  if (!conversationId) return;

  newMessageText.value = "";
  isSendingMessage.value = true;
  sendMessageError.value = null;

  try {
    const result = await alva.support.send_message({
      text: text,
      sender: "shopper",
      conversation_id: conversationId,
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

watch(() => props.supportMessages, async () => {
  await scrollChatToBottom();
}, { deep: true });
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
      <div v-if="joinChatError || sendMessageError" class="m-5 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
        {{ joinChatError || sendMessageError }}
      </div>
      <div v-if="!isChatConnected" class="flex h-[360px] flex-col items-center justify-center p-8 text-center text-sm text-zinc-500">
        <div class="mb-4 rounded-full bg-zinc-100 p-3">
          <svg class="h-6 w-6 text-zinc-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
          </svg>
        </div>
        <p>{{ chatStatus }}</p>
        <Button
          v-if="connectedCustomerName"
          variant="secondary"
          size="sm"
          class="mt-4"
          @click="joinChat"
          :disabled="isJoiningChat"
        >
          {{ isJoiningChat ? "Connecting..." : "Start Chat" }}
        </Button>
      </div>

      <div v-else ref="chatMessagesEl" class="h-[360px] space-y-4 overflow-y-auto p-4">
        <div v-if="!supportMessages?.length" class="flex h-full flex-col items-center justify-center text-sm text-zinc-500">
          <p>You're connected!</p>
          <p class="mt-1">Send a message to start the conversation.</p>
        </div>
        
        <div
          v-for="msg in supportMessages"
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
            {{ msg.text }}
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
          :disabled="!connectedCustomerName"
          @keyup.enter="sendMessage"
        />
        <Button
          variant="primary"
          @click="sendMessage"
          :disabled="!newMessageText.trim() || isSendingMessage || !connectedCustomerName"
        >
          {{ isSendingMessage ? "Sending..." : "Send" }}
        </Button>
      </div>
    </div>
  </div>
</template>
