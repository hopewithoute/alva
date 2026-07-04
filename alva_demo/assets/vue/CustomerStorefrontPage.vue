<script setup lang="ts">
import { ref, computed, watch, defineProps } from "vue";
import { api } from "../js/alva/client";
import { useChatMessages } from "./composables/useChatMessages";
import { getStatusColor } from "./utils/ui";
import Button from "./components/ui/button/Button.vue";

import type { Order, Product, Conversation, SupportMessage } from "../js/alva/types";

const props = defineProps<{
  sales_orders?: Order[];
  products?: Product[];
  support_messages?: SupportMessage[];
}>();

const customer_name = ref("");
const ordering_product_id = ref<string | null>(null);

const active_conversation = ref<Conversation | null>(null);
const historical_messages = ref<SupportMessage[]>([]);
const new_message_text = ref("");
const is_chat_open = ref(false);

const formatPrice = (cents: number) => {
  return `$${(cents / 100).toFixed(2)}`;
};

const buyProduct = async (product_id: string) => {
  ordering_product_id.value = product_id;
  const result = await api.call("sales.create_order", {
    customer_name: customer_name.value,
    product_id: product_id,
    quantity: 1
  });
  
  ordering_product_id.value = null;
  
  if (result.ok) {
    alert("Order created successfully!");
  } else {
    alert(`Failed to create order: ${result.error?.message || "Unknown error"}`);
  }
};

const joinChat = async () => {
  const result = await api.call("support.create", {
    customer_name: customer_name.value
  });
  
  if (result.ok) {
    active_conversation.value = result.data as Conversation;
    is_chat_open.value = true;
    
    const messagesRes = await api.call("support.list_messages", {
      conversation_id: active_conversation.value.id
    });
    
    if (messagesRes.ok) {
      historical_messages.value = messagesRes.data as SupportMessage[];
    }
  } else {
    alert(`Failed to join chat: ${result.error?.message || "Unknown error"}`);
  }
};

const sendMessage = async () => {
  if (!new_message_text.value.trim() || !active_conversation.value) return;
  
  const text = new_message_text.value;
  new_message_text.value = "";
  
  await api.call("support.send_message", {
    text: text,
    sender: "shopper",
    conversation_id: active_conversation.value.id
  });
};

const active_conversation_id = computed(() => active_conversation.value?.id);
const chat_messages = useChatMessages(
  active_conversation_id, 
  historical_messages, 
  computed(() => props.support_messages)
);
</script>

<template>
  <div class="rounded-lg border border-zinc-200 bg-white p-5" data-testid="customer-storefront-vue">
    <div class="flex items-center justify-between">
      <p class="text-sm font-medium text-zinc-500">Customer Storefront surface</p>
      <div class="flex items-center gap-2">
        <label for="customerName" class="text-sm font-medium text-zinc-700">Your Name:</label>
        <input 
          id="customerName" 
          v-model="customer_name" 
          type="text" 
          placeholder="e.g. Alice" 
          class="rounded-md border border-zinc-300 px-3 py-1.5 text-sm"
        />
        <Button size="sm" @click="joinChat" :disabled="!customer_name">Support Chat</Button>
      </div>
    </div>
    
    <!-- Support Chat Overlay -->
    <div v-if="is_chat_open" class="fixed bottom-4 right-4 w-80 rounded-lg border border-zinc-200 bg-white shadow-xl flex flex-col z-50">
      <div class="flex items-center justify-between border-b border-zinc-200 p-3 bg-zinc-50 rounded-t-lg">
        <h3 class="font-medium text-zinc-900">Support Chat</h3>
        <button @click="is_chat_open = false" class="text-zinc-500 hover:text-zinc-700">✕</button>
      </div>
      
      <div class="flex-1 overflow-y-auto p-4 space-y-3 h-64 bg-zinc-50/50">
        <div v-if="chat_messages.length === 0" class="text-center text-sm text-zinc-500 mt-4">
          Send a message to start the conversation.
        </div>
        <div v-for="msg in chat_messages" :key="msg.id" 
             :class="['flex', msg.sender === 'shopper' ? 'justify-end' : 'justify-start']">
          <div :class="['max-w-[80%] rounded-lg px-3 py-2 text-sm', 
               msg.sender === 'shopper' ? 'bg-blue-600 text-white' : 'bg-white border border-zinc-200 text-zinc-900']">
            {{ msg.text }}
          </div>
        </div>
      </div>
      
      <div class="border-t border-zinc-200 p-3 bg-white rounded-b-lg flex gap-2">
        <input 
          v-model="new_message_text" 
          @keyup.enter="sendMessage"
          type="text" 
          placeholder="Type a message..." 
          class="flex-1 rounded-md border border-zinc-300 px-3 py-1.5 text-sm"
        />
        <Button size="sm" @click="sendMessage" :disabled="!new_message_text.trim()">Send</Button>
      </div>
    </div>
    
    <div v-if="!props.products" class="mt-4 text-sm text-zinc-500">
      Loading catalog...
    </div>
    <div v-else class="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
      <div v-for="product in props.products" :key="product.id" class="flex flex-col overflow-hidden rounded-lg border border-zinc-200 bg-white shadow-sm">
        <div class="h-48 bg-zinc-100 flex items-center justify-center overflow-hidden">
          <img v-if="product.media_reference" :src="`/images/${product.media_reference}`" :alt="product.name" class="object-cover w-full h-full" />
          <div v-else class="text-zinc-400">No Image</div>
        </div>
        <div class="flex flex-1 flex-col p-4">
          <h3 class="text-lg font-medium text-zinc-900">{{ product.name }}</h3>
          <p class="mt-1 text-sm text-zinc-500">{{ product.description }}</p>
          <div class="mt-4 flex flex-col gap-2">
            <span class="text-sm text-zinc-600">Stock: {{ product.stock }} available</span>
          </div>
          <div class="mt-auto pt-4 flex items-center justify-between">
            <span class="text-lg font-semibold text-zinc-900">{{ formatPrice(product.price) }}</span>
            <Button 
              size="sm" 
              @click="buyProduct(product.id)" 
              :disabled="ordering_product_id === product.id || product.stock <= 0"
            >
              <span v-if="product.stock <= 0">Out of Stock</span>
              <span v-else-if="ordering_product_id === product.id">Ordering...</span>
              <span v-else>Buy</span>
            </Button>
          </div>
        </div>
      </div>
    </div>

    <!-- Orders Section -->
    <div class="mt-10 border-t border-zinc-200 pt-6">
      <h2 class="text-xl font-semibold text-zinc-900">Recent Orders</h2>
      <div v-if="!props.sales_orders" class="text-sm text-zinc-500">Loading orders...</div>
      <div v-else-if="props.sales_orders && props.sales_orders.length > 0" class="mt-4 space-y-4">
        <div v-for="order in props.sales_orders" :key="order.id" class="rounded-lg border border-zinc-200 p-4">
          <div class="flex justify-between items-center">
            <div>
              <p class="font-medium text-zinc-900">Order by {{ order.customer_name }}</p>
              <p class="text-sm text-zinc-500">Quantity: {{ order.quantity }}</p>
            </div>
            <div :class="['rounded-full px-3 py-1 text-sm font-medium capitalize', getStatusColor(order.lifecycle_status)]">
              {{ order.lifecycle_status }}
            </div>
          </div>
        </div>
      </div>
      <p v-else class="mt-4 text-sm text-zinc-500">No orders placed yet.</p>
    </div>
  </div>
</template>
