<script setup lang="ts">
import { ref } from "vue";
import { ashCall } from "../../../js/alva/client";
import type { Product, Order } from "../../../js/alva/types";
import Button from "../../shared/ui/button/Button.vue";

const props = defineProps<{
  product: Product;
  connectedCustomerName?: string | null;
}>();

const emit = defineEmits<{
  (e: "order-placed", order: Order): void;
  (e: "order-error", error: string): void;
}>();

const isOrdering = ref(false);

const formatPrice = (cents: number) => `$${(cents / 100).toFixed(2)}`;

const buyProduct = async () => {
  if (!props.connectedCustomerName) {
    emit("order-error", "Enter your name before placing an order.");
    return;
  }

  isOrdering.value = true;

  try {
    const result = await ashCall("sales.create_order", {
      customer_name: props.connectedCustomerName,
      product_id: props.product.id,
      quantity: 1,
    });

    if (result.ok) {
      emit("order-placed", result.data);
    } else {
      emit("order-error", `Failed to create order: ${result.error?.message || "Unknown error"}`);
    }
  } catch (error: any) {
    emit("order-error", error.message || "Unknown error");
  } finally {
    isOrdering.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
    <div class="flex h-48 items-center justify-center overflow-hidden bg-zinc-100">
      <img
        v-if="product.media_reference"
        :src="`/images/${product.media_reference}`"
        :alt="product.name"
        class="h-full w-full object-cover"
      />
      <div v-else class="text-zinc-400">No Image</div>
    </div>
    <div class="flex flex-1 flex-col p-5">
      <h3 class="text-lg font-medium text-zinc-900">
        {{ product.name }}
      </h3>
      <p class="mt-1 text-sm text-zinc-500">{{ product.description }}</p>
      <div class="mt-4 flex items-center justify-between text-sm">
        <span class="text-zinc-600">Stock: {{ product.stock }} available</span>
        <span class="font-semibold text-zinc-900">{{ formatPrice(product.price) }}</span>
      </div>

      <div class="mt-auto pt-5">
        <Button
          size="sm"
          class="w-full min-w-[112px]"
          @click="buyProduct"
          :disabled="isOrdering || product.stock <= 0 || !connectedCustomerName"
        >
          <span v-if="product.stock <= 0">Out of Stock</span>
          <span v-else-if="isOrdering">Ordering...</span>
          <span v-else>Buy Now</span>
        </Button>
      </div>
    </div>
  </div>
</template>
