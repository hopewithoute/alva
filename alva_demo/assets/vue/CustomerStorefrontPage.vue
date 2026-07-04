<script setup lang="ts">
import { ref } from "vue";
import { useAlvaApi, ashQuery } from "alva";
import Button from "./components/ui/button/Button.vue";

const api = useAlvaApi();
const { data: products, loading: productsLoading, error: productsError } = ashQuery(api as any, "catalog.list_products");
const { data: orders, fetch: fetchOrders } = ashQuery(api as any, "sales.list_orders");

const customerName = ref("");
const orderingProductId = ref<string | null>(null);

const formatPrice = (cents: number) => {
  return `$${(cents / 100).toFixed(2)}`;
};

const buyProduct = async (productId: string) => {
  if (!customerName.value) {
    alert("Please enter your name first!");
    return;
  }
  
  orderingProductId.value = productId;
  const result = await api.call("sales.create_order" as any, {
    customer_name: customerName.value,
    product_id: productId,
    quantity: 1
  });
  
  orderingProductId.value = null;
  
  if (result.ok) {
    alert("Order placed successfully!");
    fetchOrders();
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
          v-model="customerName" 
          type="text" 
          placeholder="e.g. Alice" 
          class="rounded-md border border-zinc-300 px-3 py-1.5 text-sm"
        />
      </div>
    </div>
    
    <div v-if="productsLoading" class="mt-4">
      Loading catalog...
    </div>
    <div v-else-if="productsError" class="mt-4 text-red-500">
      Error loading catalog: {{ productsError.message }}
    </div>
    <div v-else class="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
      <div v-for="product in products" :key="product.id" class="flex flex-col overflow-hidden rounded-lg border border-zinc-200 bg-white shadow-sm">
        <div class="h-48 bg-zinc-100 flex items-center justify-center overflow-hidden">
          <img v-if="product.media_reference" :src="`/images/${product.media_reference}`" :alt="product.name" class="object-cover w-full h-full" />
          <div v-else class="text-zinc-400">No Image</div>
        </div>
        <div class="flex flex-1 flex-col p-4">
          <h3 class="text-lg font-medium text-zinc-900">{{ product.name }}</h3>
          <p class="mt-1 text-sm text-zinc-500">{{ product.description }}</p>
          <div class="mt-auto pt-4 flex items-center justify-between">
            <span class="text-lg font-semibold text-zinc-900">{{ formatPrice(product.price) }}</span>
            <Button 
              size="sm" 
              @click="buyProduct(product.id)" 
              :disabled="orderingProductId === product.id"
            >
              {{ orderingProductId === product.id ? 'Ordering...' : 'Buy' }}
            </Button>
          </div>
        </div>
      </div>
    </div>

    <!-- Orders Section -->
    <div class="mt-10 border-t border-zinc-200 pt-6">
      <h2 class="text-xl font-semibold text-zinc-900">Recent Orders</h2>
      <div v-if="orders && orders.length > 0" class="mt-4 space-y-4">
        <div v-for="order in orders" :key="order.id" class="rounded-lg border border-zinc-200 p-4">
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
