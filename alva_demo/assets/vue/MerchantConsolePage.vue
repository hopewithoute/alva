<script setup lang="ts">
import { ref, computed, watch, defineProps } from "vue";
import { useAlvaApi as use_alva_api, ashUpload as ash_upload } from "alva";
import Button from "./components/ui/button/Button.vue";

import { Order, Product, Conversation, SupportMessage } from "./types";

const props = defineProps<{
  sales_orders?: Order[];
  products?: Product[];
  conversations?: Conversation[];
  support_messages?: SupportMessage[];
}>();

const api = use_alva_api();

const transitioning_order_id = ref<string | null>(null);
const operation_error = ref<string | null>(null);

const adjusting_product_id = ref<string | null>(null);
const adjustment_error = ref<string | null>(null);
const stock_input = ref<Record<string, number>>({});

const media_upload = ash_upload("media", { maxFiles: 1 });
const uploading_media_product_id = ref<string | null>(null);
const upload_error = ref<string | null>(null);

const active_conversation_id = ref<string | null>(null);
const historical_messages = ref<SupportMessage[]>([]);
const new_message_text = ref("");

const triggerMediaUpload = (productId: string) => {
  uploading_media_product_id.value = productId;
  upload_error.value = null;
  media_upload.showFilePicker();
};

watch(media_upload.progress, async (newProgress) => {
  if (newProgress === 100 && media_upload.files.value.length > 0 && uploading_media_product_id.value) {
    const refs = media_upload.getFileReferences();
    if (refs.length > 0) {
      const productId = uploading_media_product_id.value;
      const result = await api.ashCall("catalog.upload_media", { 
        id: productId, 
        media: refs[0] 
      });
      
      media_upload.clear();
      uploading_media_product_id.value = null;
      
      if (!result.ok) {
        upload_error.value = `Failed to upload media: ${result.error.message}`;
      }
    }
  }
});

const beginProcessing = async (orderId: string) => {
  transitioning_order_id.value = orderId;
  operation_error.value = null;
  
  const result = await api.ashCall("sales.begin_processing", { id: orderId });
  transitioning_order_id.value = null;
  
  if (!result.ok) {
    operation_error.value = `Failed to begin processing: ${result.error.message}`;
  }
};

const fulfill = async (orderId: string) => {
  transitioning_order_id.value = orderId;
  operation_error.value = null;
  
  const result = await api.ashCall("sales.fulfill", { id: orderId });
  transitioning_order_id.value = null;
  
  if (!result.ok) {
    operation_error.value = `Failed to fulfill order: ${result.error.message}`;
  }
};

const adjustStock = async (productId: string) => {
  let newStock = stock_input.value[productId];
  if (newStock === undefined) {
    const p = props.products?.find(p => p.id === productId);
    if (p) newStock = p.stock;
  }
  if (newStock === undefined || newStock < 0) return;

  adjusting_product_id.value = productId;
  adjustment_error.value = null;
  
  const result = await api.ashCall("catalog.adjust_stock", { 
    id: productId,
    stock: newStock 
  });
  
  adjusting_product_id.value = null;
  
  if (!result.ok) {
    adjustment_error.value = `Failed to adjust stock: ${result.error.message}`;
  }
};

const selectConversation = async (conversationId: string) => {
  active_conversation_id.value = conversationId;
  historical_messages.value = [];
  
  const messagesRes = await api.ashCall("support.list_messages", {
    conversation_id: conversationId
  });
  
  if (messagesRes.ok) {
    historical_messages.value = messagesRes.data as SupportMessage[];
  }
};

const sendReply = async () => {
  if (!new_message_text.value.trim() || !active_conversation_id.value) return;
  
  const text = new_message_text.value;
  new_message_text.value = "";
  
  await api.ashCall("support.send_message", {
    text: text,
    sender: "merchant",
    conversation_id: active_conversation_id.value
  });
};

const chat_messages = computed(() => {
  if (!active_conversation_id.value) return [];
  
  const mergedMap = new Map<string, SupportMessage>();
  historical_messages.value.forEach(m => mergedMap.set(m.id, m));
  
  if (props.support_messages) {
    props.support_messages.forEach(m => {
      if (m.conversation_id === active_conversation_id.value) {
        mergedMap.set(m.id, m);
      }
    });
  }
  
  return Array.from(mergedMap.values()).sort((a, b) => 
    new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
  );
});

const getProductName = (productId: string) => {
  if (!props.products) return productId;
  const p = props.products.find((p: any) => p.id === productId);
  return p ? p.name : productId;
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'new': return 'bg-blue-50 text-blue-700 border-blue-200';
    case 'processing': return 'bg-amber-50 text-amber-700 border-amber-200';
    case 'fulfilled': return 'bg-emerald-50 text-emerald-700 border-emerald-200';
    default: return 'bg-zinc-50 text-zinc-700 border-zinc-200';
  }
};
</script>

<template>
  <div class="space-y-6" data-testid="merchant-console-vue">
    <div class="flex items-center justify-between">
      <p class="text-sm font-medium text-zinc-500">Merchant Console surface</p>
    </div>

    <!-- Order Lifecycle Section -->
    <div class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-xl font-semibold">Order Lifecycle</h2>
        <div class="flex gap-2">
          <span class="inline-flex items-center rounded-full bg-zinc-100 px-2.5 py-0.5 text-xs font-medium text-zinc-800">
            {{ props.sales_orders?.length || 0 }} total
          </span>
        </div>
      </div>

      <div v-if="operation_error" class="mb-4 rounded-md bg-red-50 p-4 text-sm text-red-700">
        {{ operation_error }}
      </div>

      <div v-if="!props.sales_orders" class="text-sm text-zinc-500">Loading orders...</div>
      <div v-else-if="props.sales_orders.length === 0" class="text-sm text-zinc-500 italic">No orders yet.</div>
      <div v-else class="space-y-3">
        <div v-for="order in props.sales_orders" :key="order.id" class="flex flex-col sm:flex-row sm:items-center justify-between rounded-lg border border-zinc-200 p-4 hover:bg-zinc-50 transition-colors">
          <div class="mb-4 sm:mb-0">
            <p class="font-medium text-zinc-900">Order by <span class="font-semibold">{{ order.customer_name }}</span></p>
            <p class="text-sm text-zinc-500 mt-1">
              {{ getProductName(order.product_id) }} (Qty: {{ order.quantity }})
            </p>
          </div>
          
          <div class="flex items-center gap-4">
            <div :class="['rounded-full border px-3 py-1 text-sm font-medium capitalize', getStatusColor(order.lifecycle_status)]">
              {{ order.lifecycle_status }}
            </div>
            
            <div class="flex gap-2 min-w-[100px] justify-end">
              <Button 
                v-if="order.lifecycle_status === 'new'"
                size="sm"
                @click="beginProcessing(order.id)"
                :disabled="transitioning_order_id === order.id"
              >
                {{ transitioning_order_id === order.id ? '...' : 'Process' }}
              </Button>
              
              <Button 
                v-if="order.lifecycle_status === 'processing'"
                size="sm"
                @click="fulfill(order.id)"
                :disabled="transitioning_order_id === order.id"
              >
                {{ transitioning_order_id === order.id ? '...' : 'Fulfill' }}
              </Button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Inventory Snapshot Section -->
    <div class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-xl font-semibold">Inventory Snapshot</h2>
      </div>

      <div v-if="adjustment_error" class="mb-4 rounded-md bg-red-50 p-4 text-sm text-red-700">
        {{ adjustment_error }}
      </div>
      
      <div v-if="upload_error" class="mb-4 rounded-md bg-red-50 p-4 text-sm text-red-700">
        {{ upload_error }}
      </div>

      <div v-if="!props.products" class="text-sm text-zinc-500">Loading inventory...</div>
      <div v-else class="space-y-4">
        <div v-for="product in props.products" :key="product.id" class="flex flex-col sm:flex-row sm:items-center justify-between rounded-lg border border-zinc-200 p-4 gap-4">
          <div class="flex items-center gap-4">
            <div v-if="product.media_reference" class="h-12 w-12 rounded bg-zinc-100 overflow-hidden shrink-0 border border-zinc-200">
              <img :src="`/images/${product.media_reference}`" class="w-full h-full object-cover" />
            </div>
            <div v-else class="h-12 w-12 rounded bg-zinc-100 flex items-center justify-center shrink-0 border border-zinc-200 text-xs text-zinc-400">
              No img
            </div>
            <div>
              <p class="font-medium text-zinc-900">{{ product.name }}</p>
              <p class="text-sm text-zinc-500">Current Stock: {{ product.stock }}</p>
            </div>
          </div>
          
          <div class="flex items-center gap-3">
            <input 
              type="number"
              min="0"
              class="w-24 rounded-md border border-zinc-300 px-3 py-1.5 text-sm"
              :value="stock_input[product.id] ?? product.stock"
              @input="e => stock_input[product.id] = parseInt((e.target as HTMLInputElement).value) || 0"
            />
            <Button 
              size="sm"
              variant="outline"
              @click="adjustStock(product.id)"
              :disabled="adjusting_product_id === product.id"
            >
              {{ adjusting_product_id === product.id ? 'Saving...' : 'Update Stock' }}
            </Button>
            
            <div class="flex flex-col gap-1 w-28">
              <Button 
                size="sm"
                variant="outline"
                @click="triggerMediaUpload(product.id)"
                :disabled="uploading_media_product_id === product.id"
              >
                {{ uploading_media_product_id === product.id ? 'Uploading...' : 'Upload Media' }}
              </Button>
              <div v-if="uploading_media_product_id === product.id" class="w-full bg-zinc-200 h-1.5 rounded-full overflow-hidden">
                <div class="bg-blue-600 h-full transition-all duration-300" :style="{ width: `${media_upload.progress.value}%` }"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Support Chat Section -->
    <div class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm flex flex-col h-[500px]">
      <h2 class="text-xl font-semibold mb-4">Support Chat</h2>
      <div class="flex flex-1 overflow-hidden border border-zinc-200 rounded-lg">
        <!-- Conversation List -->
        <div class="w-1/3 border-r border-zinc-200 bg-zinc-50 overflow-y-auto">
          <div v-if="!props.conversations || props.conversations.length === 0" class="p-4 text-sm text-zinc-500">
            No active conversations.
          </div>
          <div v-else>
            <div v-for="conv in props.conversations" :key="conv.id"
                 @click="selectConversation(conv.id)"
                 :class="['p-4 cursor-pointer border-b border-zinc-200 hover:bg-zinc-100 transition-colors',
                          active_conversation_id === conv.id ? 'bg-zinc-200 font-medium' : '']">
              {{ conv.customer_name }}
            </div>
          </div>
        </div>
        
        <!-- Chat Area -->
        <div class="flex-1 flex flex-col bg-white">
          <div v-if="!active_conversation_id" class="flex-1 flex items-center justify-center text-sm text-zinc-500">
            Select a conversation to reply.
          </div>
          <template v-else>
            <div class="p-3 border-b border-zinc-200 bg-white">
              <h3 class="font-medium">
                Chatting with {{ props.conversations?.find(c => c.id === active_conversation_id)?.customer_name }}
              </h3>
            </div>
            <div class="flex-1 overflow-y-auto p-4 space-y-3 bg-zinc-50/30">
              <div v-if="chat_messages.length === 0" class="text-center text-sm text-zinc-500 mt-4">
                No messages yet.
              </div>
              <div v-for="msg in chat_messages" :key="msg.id" 
                   :class="['flex', msg.sender === 'merchant' ? 'justify-end' : 'justify-start']">
                <div :class="['max-w-[80%] rounded-lg px-3 py-2 text-sm', 
                     msg.sender === 'merchant' ? 'bg-blue-600 text-white' : 'bg-white border border-zinc-200 text-zinc-900']">
                  {{ msg.text }}
                </div>
              </div>
            </div>
            
            <div class="border-t border-zinc-200 p-3 bg-white flex gap-2">
              <input 
                v-model="new_message_text" 
                @keyup.enter="sendReply"
                type="text" 
                placeholder="Type a reply..." 
                class="flex-1 rounded-md border border-zinc-300 px-3 py-1.5 text-sm"
              />
              <Button size="sm" @click="sendReply" :disabled="!new_message_text.trim()">Send</Button>
            </div>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>
