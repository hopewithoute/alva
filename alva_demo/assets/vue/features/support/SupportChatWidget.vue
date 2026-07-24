<script setup lang="ts">
import { ref, nextTick, computed, watchPostEffect } from "vue";
import type { SupportMessage } from "@/js/alva/types";
import { useAlva } from "@/js/alva";
import Button from "@/vue/shared/ui/button/Button.vue";
import { MESSAGE_SENDER } from "@/vue/features/merchant/types";
import { useRouteQueryPatch } from "@/vue/shared/useRouteQueryPatch";
import { getErrorMessage } from "@/vue/utils/error";

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
      customer_name: props.connectedCustomerName
    });

    if (!result.ok) {
      joinChatError.value = result.error?.message || "Failed to create support conversation.";
      return null;
    }

    const conversationId = result.data?.id || null;

    patchQuery(
      {
        customer_name: props.connectedCustomerName,
        conversation_id: conversationId
      },
      { replace: false }
    );

    await scrollChatToBottom();
    return conversationId;
  } catch (error: unknown) {
    joinChatError.value = getErrorMessage(error);
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
      conversation_id: conversationId
    });

    if (!result.ok) {
      sendMessageError.value = result.error?.message || "Failed to send message.";
      newMessageText.value = text;
    } else {
      await scrollChatToBottom();
    }
  } catch (err: unknown) {
    sendMessageError.value = getErrorMessage(err);
    newMessageText.value = text;
  } finally {
    isSendingMessage.value = false;
  }
};

watchPostEffect(() => {
  if (props.supportMessages && chatMessagesEl.value) {
    chatMessagesEl.value.scrollTop = chatMessagesEl.value.scrollHeight;
  }
});
</script>

<template>
  <div
    class="flex h-full min-h-[620px] flex-col border border-[var(--color-rule)] bg-[var(--color-paper)] xl:sticky xl:top-24"
  >
    <div class="space-y-2 border-b border-[var(--color-rule)] p-6">
      <div class="flex items-start justify-between gap-3">
        <div>
          <p
            class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
            style="font-family: var(--font-mono)"
          >
            Support Chat
          </p>
          <p
            class="mt-2 text-xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            {{ chatStatus }}
          </p>
        </div>
        <span
          class="border border-[var(--color-rule)] px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          {{ isChatConnected ? "live" : "standby" }}
        </span>
      </div>
    </div>

    <div class="flex-1 overflow-y-auto bg-[var(--color-paper-2)]">
      <div
        v-if="joinChatError || sendMessageError"
        class="m-5 border border-danger-border bg-danger-surface p-3 text-sm italic text-danger"
        style="font-family: var(--font-display)"
      >
        {{ joinChatError || sendMessageError }}
      </div>
      <div
        v-if="!isChatConnected"
        class="flex h-[360px] flex-col items-center justify-center p-8 text-center text-sm text-[var(--color-ink-2)]"
      >
        <p class="italic" style="font-family: var(--font-display)">{{ chatStatus }}</p>
        <Button
          v-if="connectedCustomerName"
          variant="secondary"
          size="sm"
          class="btn--primary mt-6 px-6 py-2 text-xs"
          @click="joinChat"
          :disabled="isJoiningChat"
        >
          {{ isJoiningChat ? "Connecting..." : "Start Chat" }}
        </Button>
      </div>

      <div v-else ref="chatMessagesEl" class="h-[360px] space-y-4 overflow-y-auto p-6">
        <div
          v-if="!supportMessages?.length"
          class="flex h-full flex-col items-center justify-center text-sm italic text-[var(--color-ink-2)]"
          style="font-family: var(--font-display)"
        >
          <p>You're connected!</p>
          <p class="mt-1">Send a message to start the conversation.</p>
        </div>

        <div
          v-for="msg in supportMessages"
          :key="msg.id"
          class="flex"
          :class="msg.sender === MESSAGE_SENDER.SHOPPER ? 'justify-end' : 'justify-start'"
        >
          <div
            class="max-w-[85%] px-4 py-2 text-sm"
            :class="
              msg.sender === MESSAGE_SENDER.SHOPPER
                ? 'bg-[var(--color-accent)] text-[var(--color-accent-ink)]'
                : 'border border-[var(--color-rule)] bg-[var(--color-paper)] text-[var(--color-ink)]'
            "
          >
            {{ msg.text }}
          </div>
        </div>
      </div>
    </div>

    <div class="border-t border-[var(--color-rule)] bg-[var(--color-paper)] p-4">
      <div class="flex gap-4">
        <input
          v-model="newMessageText"
          type="text"
          placeholder="Type a message..."
          class="flex-1 rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 text-sm text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0 disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="!connectedCustomerName"
          @keyup.enter="sendMessage"
        />
        <Button
          class="btn--primary px-6 text-xs"
          @click="sendMessage"
          :disabled="!newMessageText.trim() || isSendingMessage || !connectedCustomerName"
        >
          {{ isSendingMessage ? "Sending..." : "Send" }}
        </Button>
      </div>
    </div>
  </div>
</template>
