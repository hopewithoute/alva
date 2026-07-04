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

const customer_name = ref("");
const ordering_product_id = ref<string | null>(null);

const formatPrice = (cents: number) => {
  return `$${(cents / 100).toFixed(2)}`;
};

const buyProduct = async (productId: string) => {
  if (!customer_name.value) {
    alert("Please enter your name first!");
    return;
  }
  
  ordering_product_id.value = productId;
  const result = await api.call("sales.create_order" as any, {
    customer_name: customer_name.value,
    product_id: productId,
    quantity: 1
  });
  
  ordering_product_id.value = null;
  
  if (result.ok) {
    alert("Order placed successfully!");
    // Rely on server stream to update UI
    customer_name.value = "";
  } else {
    alert(`Failed to place order: ${result.error.message}`);
  }
};
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
            <div class="rounded-full bg-blue-50 px-3 py-1 text-sm font-medium text-blue-700 capitalize">
              {{ order.lifecycle_status }}
            </div>
          </div>
        </div>
      </div>
      <p v-else class="mt-4 text-sm text-zinc-500">No orders placed yet.</p>
    </div>
  </div>
</template>
