<script setup lang="ts">
import { ref } from "vue";
import { useAlvaApi, ashQuery } from "alva";
import Button from "./components/ui/button/Button.vue";

const api = useAlvaApi();

const { data: orders, loading: ordersLoading, error: ordersError, fetch: fetchOrders } = ashQuery(api as any, "sales.list_orders");
const { data: products, loading: productsLoading, error: productsError } = ashQuery(api as any, "catalog.list_products");

const transitioningOrderId = ref<string | null>(null);
const operationError = ref<string | null>(null);

const beginProcessing = async (orderId: string) => {
  operationError.value = null;
  transitioningOrderId.value = orderId;
  const result = await api.call("sales.begin_processing" as any, { id: orderId });
  transitioningOrderId.value = null;

  if (result.ok) {
    fetchOrders();
  } else {
    operationError.value = `Failed to begin processing: ${result.error.message}`;
  }
};

const fulfill = async (orderId: string) => {
  operationError.value = null;
  transitioningOrderId.value = orderId;
  const result = await api.call("sales.fulfill" as any, { id: orderId });
  transitioningOrderId.value = null;

  if (result.ok) {
    fetchOrders();
  } else {
    operationError.value = `Failed to fulfill order: ${result.error.message}`;
  }
};

const STATUS_COLORS: Record<string, string> = {
  'new': 'bg-blue-50 text-blue-700 border-blue-200',
  'processing': 'bg-amber-50 text-amber-700 border-amber-200',
  'fulfilled': 'bg-green-50 text-green-700 border-green-200',
  'cancelled': 'bg-red-50 text-red-700 border-red-200'
};

const getStatusColor = (status: string) => {
  return STATUS_COLORS[status] || 'bg-zinc-50 text-zinc-700 border-zinc-200';
};
</script>

<template>
  <div class="space-y-8" data-testid="merchant-console-vue">
    <div v-if="operationError" class="rounded-md bg-red-50 p-4 border border-red-200">
      <p class="text-sm text-red-700">{{ operationError }}</p>
    </div>

    <!-- Orders Section -->
    <div class="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm">
      <h2 class="text-xl font-semibold text-zinc-900 mb-4">Orders</h2>
      
      <div v-if="ordersLoading" class="text-sm text-zinc-500">Loading orders...</div>
      <div v-else-if="ordersError" class="text-sm text-red-500">{{ ordersError.message }}</div>
      <div v-else-if="orders && orders.length === 0" class="text-sm text-zinc-500">No orders found.</div>
      <div v-else class="space-y-4">
        <div v-for="order in orders" :key="order.id" class="flex flex-col sm:flex-row sm:items-center justify-between rounded-lg border border-zinc-200 p-4 gap-4">
          <div>
            <p class="font-medium text-zinc-900">Order by {{ order.customer_name }}</p>
            <p class="text-sm text-zinc-500">Quantity: {{ order.quantity }} &middot; Product ID: {{ order.product_id }}</p>
          </div>
          
          <div class="flex items-center gap-3">
            <span :class="['px-3 py-1 rounded-full text-sm font-medium border', getStatusColor(order.lifecycle_status)]">
              {{ order.lifecycle_status }}
            </span>
            
            <Button 
              v-if="order.lifecycle_status === 'new'" 
              size="sm" 
              variant="outline"
              @click="beginProcessing(order.id)"
              :disabled="transitioningOrderId === order.id"
            >
              {{ transitioningOrderId === order.id ? 'Processing...' : 'Begin Processing' }}
            </Button>
            
            <Button 
              v-else-if="order.lifecycle_status === 'processing'" 
              size="sm" 
              variant="default"
              @click="fulfill(order.id)"
              :disabled="transitioningOrderId === order.id"
            >
              {{ transitioningOrderId === order.id ? 'Fulfilling...' : 'Fulfill Order' }}
            </Button>
          </div>
        </div>
      </div>
    </div>

    <!-- Inventory Snapshot Section -->
    <div class="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm">
      <h2 class="text-xl font-semibold text-zinc-900 mb-4">Inventory Snapshot</h2>
      
      <div v-if="productsLoading" class="text-sm text-zinc-500">Loading inventory...</div>
      <div v-else-if="productsError" class="text-sm text-red-500">{{ productsError.message }}</div>
      <div v-else-if="products && products.length === 0" class="text-sm text-zinc-500">No products found.</div>
      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <div v-for="product in products" :key="product.id" class="rounded-lg border border-zinc-200 p-4 flex items-center gap-4">
          <div class="h-16 w-16 bg-zinc-100 rounded flex items-center justify-center overflow-hidden flex-shrink-0">
            <img v-if="product.media_reference" :src="`/images/${product.media_reference}`" :alt="product.name" class="object-cover w-full h-full" />
            <span v-else class="text-xs text-zinc-400">No Img</span>
          </div>
          <div>
            <p class="font-medium text-zinc-900 truncate" :title="product.name">{{ product.name }}</p>
            <p class="text-sm font-semibold mt-1" :class="product.stock > 10 ? 'text-green-600' : 'text-red-600'">
              {{ product.stock }} in stock
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
