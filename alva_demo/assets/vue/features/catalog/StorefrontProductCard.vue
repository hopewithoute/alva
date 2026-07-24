<script setup lang="ts">
import { ref } from "vue";
import { useAlva } from "@/js/alva";
import type { Product, Order } from "@/js/alva/types";
import Button from "@/vue/shared/ui/button/Button.vue";
import { getErrorMessage } from "@/vue/utils/error";
import { formatPrice } from "@/vue/utils/format";

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
      quantity: 1
    });

    if (result.ok) {
      emit("order-placed", result.data);
    } else {
      emit("order-error", `Failed to create order: ${result.error?.message || "Unknown error"}`);
    }
  } catch (error: unknown) {
    emit("order-error", getErrorMessage(error));
  } finally {
    isOrdering.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col border-b border-[var(--color-rule)] pb-8 pt-4">
    <div
      class="flex h-56 items-center justify-center overflow-hidden border border-[var(--color-rule)] bg-[var(--color-paper-2)]"
    >
      <img
        v-if="product.media_reference"
        :src="`/images/${product.media_reference}`"
        :alt="product.name"
        class="h-full w-full object-cover"
      />
      <div
        v-else
        class="text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
        style="font-family: var(--font-mono)"
      >
        No Image
      </div>
    </div>
    <div class="flex flex-1 flex-col pt-6">
      <div class="flex items-baseline justify-between gap-4">
        <h3
          class="text-2xl font-normal text-[var(--color-ink)]"
          style="font-family: var(--font-display)"
        >
          {{ product.name }}
        </h3>
        <span
          class="text-lg font-normal text-[var(--color-ink)]"
          style="font-family: var(--font-display)"
          >{{ formatPrice(product.price) }}</span
        >
      </div>
      <p class="mt-2 text-sm text-[var(--color-ink-2)]" style="line-height: 1.6">
        {{ product.description }}
      </p>
      <div
        class="mt-4 flex items-center justify-between text-xs uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
        style="font-family: var(--font-mono)"
      >
        <span>Stock: {{ product.stock }} available</span>
      </div>

      <div class="mt-6">
        <Button
          size="sm"
          class="btn--primary w-full py-3 text-xs"
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
