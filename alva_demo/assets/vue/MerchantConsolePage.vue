<script setup lang="ts">
import { ref, defineProps } from "vue";
import { useAlvaApi } from "alva";
import Button from "./components/ui/button/Button.vue";

import { Order, Product } from "./types";

const props = defineProps<{
  sales_orders?: Order[];
  products?: Product[];
}>();

const api = useAlvaApi();

const transitioningOrderId = ref<string | null>(null);
const operationError = ref<string | null>(null);

const adjustingProductId = ref<string | null>(null);
const adjustmentError = ref<string | null>(null);
const stockInput = ref<Record<string, number>>({});

const beginProcessing = async (orderId: string) => {
  transitioningOrderId.value = orderId;
  operationError.value = null;
  
  const result = await api.call("sales.begin_processing" as any, { id: orderId });
  transitioningOrderId.value = null;
  
  if (!result.ok) {
    operationError.value = `Failed to begin processing: ${result.error.message}`;
  }
};

const fulfill = async (orderId: string) => {
  transitioningOrderId.value = orderId;
  operationError.value = null;
  
  const result = await api.call("sales.fulfill" as any, { id: orderId });
  transitioningOrderId.value = null;
  
  if (!result.ok) {
    operationError.value = `Failed to fulfill order: ${result.error.message}`;
  }
};

const adjustStock = async (productId: string) => {
  let newStock = stockInput.value[productId];
  if (newStock === undefined) {
    const p = props.products?.find(p => p.id === productId);
    if (p) newStock = p.stock;
  }
  if (newStock === undefined || newStock < 0) return;

  adjustingProductId.value = productId;
  adjustmentError.value = null;
  
  const result = await api.call("catalog.adjust_stock" as any, { 
    id: productId,
    stock: newStock 
  });
  
  adjustingProductId.value = null;
  
  if (!result.ok) {
    adjustmentError.value = `Failed to adjust stock: ${result.error.message}`;
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

      <div v-if="adjustmentError" class="mb-4 rounded-md bg-red-50 p-4 text-sm text-red-700">
        {{ adjustmentError }}
      </div>

      <div v-if="!props.products" class="text-sm text-zinc-500">Loading inventory...</div>
      <div v-else class="space-y-4">
        <div v-for="product in props.products" :key="product.id" class="flex flex-col sm:flex-row sm:items-center justify-between rounded-lg border border-zinc-200 p-4 gap-4">
          <div>
            <p class="font-medium text-zinc-900">{{ product.name }}</p>
            <p class="text-sm text-zinc-500">Current Stock: {{ product.stock }}</p>
          </div>
          
          <div class="flex items-center gap-3">
            <input 
              type="number"
              min="0"
              class="w-24 rounded-md border border-zinc-300 px-3 py-1.5 text-sm"
              :value="stockInput[product.id] ?? product.stock"
              @input="e => stockInput[product.id] = parseInt((e.target as HTMLInputElement).value) || 0"
            />
            <Button 
              size="sm"
              variant="outline"
              @click="adjustStock(product.id)"
              :disabled="adjustingProductId === product.id"
            >
              {{ adjustingProductId === product.id ? 'Saving...' : 'Update Stock' }}
            </Button>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>
