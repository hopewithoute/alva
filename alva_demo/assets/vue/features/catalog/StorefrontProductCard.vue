<script setup lang="ts">
import { ref } from "vue";
import { useAlva } from "../../../js/alva";
import type { Product, Order } from "../../../js/alva/types";
import Button from "../../shared/ui/button/Button.vue";

const props = defineProps<{
  product: Product;
  connectedCustomerName?: string | null;
}>();

const alva = useAlva();

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
    const result = await alva.sales.create_order({
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
  <div class="flex flex-col overflow-hidden rounded-xl border border-[var(--color-rule)] bg-[var(--color-paper)] shadow-sm">
    <div class="flex h-48 items-center justify-center overflow-hidden bg-[var(--color-rule)]">
      <img
        v-if="product.media_reference"
        :src="`/images/${product.media_reference}`"
        :alt="product.name"
        class="h-full w-full object-cover"
      />
      <div v-else class="text-[var(--color-ink-2)]">No Image</div>
    </div>
    <div class="flex flex-1 flex-col p-5">
      <h3 class="text-lg font-medium text-[var(--color-ink)]" style="font-family: var(--font-display);">
        {{ product.name }}
      </h3>
      <p class="mt-1 text-sm text-[var(--color-ink-2)]">{{ product.description }}</p>
      <div class="mt-4 flex items-center justify-between text-sm">
        <span class="text-[var(--color-ink-2)]">Stock: {{ product.stock }} available</span>
        <span class="font-semibold text-[var(--color-ink)]">{{ formatPrice(product.price) }}</span>
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
