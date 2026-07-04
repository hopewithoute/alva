<script setup lang="ts">
import { useAlvaApi, ashQuery } from "alva";

const api = useAlvaApi();
const { data: products, loading, error } = ashQuery(api as any, "catalog.list_products");
</script>

<template>
  <div class="rounded-lg border border-zinc-200 bg-white p-5" data-testid="customer-storefront-vue">
    <p class="text-sm font-medium text-zinc-500">Customer Storefront surface</p>
    
    <div v-if="loading" class="mt-4">
      Loading catalog...
    </div>
    <div v-else-if="error" class="mt-4 text-red-500">
      Error loading catalog: {{ error.message }}
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
            <span class="text-lg font-semibold text-zinc-900">${{ (product.price / 100).toFixed(2) }}</span>
            <span class="text-sm text-zinc-500">{{ product.stock }} in stock</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
