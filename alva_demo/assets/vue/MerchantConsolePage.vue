<script setup lang="ts">
import { ref, defineProps, watch } from "vue";
import { useAlvaApi as use_alva_api, ashUpload as ash_upload } from "alva";
import Button from "./components/ui/button/Button.vue";

import { Order, Product } from "./types";

const props = defineProps<{
  sales_orders?: Order[];
  products?: Product[];
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
    <!-- Active Orders Section -->
    <div class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-xl font-semibold">Active Orders</h2>
      </div>

      <div v-if="operationError" class="mb-4 rounded-md bg-red-50 p-4 text-sm text-red-700">
        {{ operationError }}
      </div>

      <div v-if="!props.sales_orders" class="text-sm text-zinc-500">Loading orders...</div>
      <div v-else-if="props.sales_orders && props.sales_orders.length === 0" class="text-sm text-zinc-500">No orders found.</div>
      <div v-else class="space-y-4">
        <div v-for="order in props.sales_orders" :key="order.id" class="flex flex-col sm:flex-row sm:items-center justify-between rounded-lg border border-zinc-200 p-4 gap-4">
          <div>
            <p class="font-medium text-zinc-900">Order by {{ order.customer_name }}</p>
            <p class="text-sm text-zinc-500">
              Quantity: {{ order.quantity }} &middot; 
              Product: {{ !props.products ? 'Loading...' : getProductName(order.product_id) }}
            </p>
          </div>
          
          <div class="flex items-center gap-3">
            <div :class="['rounded-full border px-3 py-1 text-sm font-medium capitalize', getStatusColor(order.lifecycle_status)]">
              {{ order.lifecycle_status }}
            </div>
            
            <div class="flex gap-2 min-w-[100px] justify-end">
              <Button 
                v-if="order.lifecycle_status === 'new'"
                size="sm"
                @click="beginProcessing(order.id)"
                :disabled="transitioningOrderId === order.id"
              >
                {{ transitioningOrderId === order.id ? '...' : 'Process' }}
              </Button>
              
              <Button 
                v-if="order.lifecycle_status === 'processing'"
                size="sm"
                @click="fulfill(order.id)"
                :disabled="transitioningOrderId === order.id"
              >
                {{ transitioningOrderId === order.id ? '...' : 'Fulfill' }}
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

  </div>
</template>
