<script setup lang="ts">
import { ref } from "vue";
import { useAlva } from "@/js/alva";
import type { Product } from "@/js/alva/types";
import Button from "@/vue/shared/ui/button/Button.vue";
import { getErrorMessage } from "@/vue/utils/error";
import { formatPrice } from "@/vue/utils/format";
import { cn } from "@/vue/lib/utils";

const props = defineProps<{
  product: Product;
  isUploading?: boolean;
  uploadProgress?: number;
  uploadError?: string | null;
}>();

const emit = defineEmits<{
  (e: "requestUpload"): void;
}>();

const alva = useAlva();

const stockForm = alva.catalog.use_adjust_stock_form({
  initialValues: {
    id: props.product.id,
    stock: props.product.stock
  }
});

const isAdjusting = ref(false);
const adjustmentError = ref();

const adjustStock = async () => {
  if ((stockForm.field("stock").value.value ?? 0) < 0 || isAdjusting.value) return;

  isAdjusting.value = true;
  adjustmentError.value = null;

  try {
    const result = await stockForm.submit();

    if (!result.ok) {
      adjustmentError.value = result.error?.message || "Failed to update stock.";
    }
  } catch (error: unknown) {
    adjustmentError.value = getErrorMessage(error);
  } finally {
    isAdjusting.value = false;
  }
};

const getProductStockTone = () => {
  if (props.product.stock <= 0) return "bg-danger-surface text-danger border-danger-border";
  if (props.product.stock <= 25) return "bg-warning-surface text-warning border-warning-border";
  return "bg-success-surface text-success border-success-border";
};
</script>

<template>
  <div
    class="flex flex-col gap-6 border-b border-[var(--color-rule)] pb-6 pt-4 lg:flex-row lg:items-center lg:justify-between"
  >
    <div class="flex min-w-0 items-start gap-4">
      <div
        v-if="product.media_reference"
        class="h-16 w-16 shrink-0 overflow-hidden border border-[var(--color-rule)] bg-[var(--color-paper-2)]"
      >
        <img :src="`/images/${product.media_reference}`" class="h-full w-full object-cover" />
      </div>
      <div
        v-else
        class="flex h-16 w-16 shrink-0 items-center justify-center border border-[var(--color-rule)] bg-[var(--color-paper-2)] font-mono text-[10px] uppercase text-[var(--color-ink-2)]"
      >
        No img
      </div>

      <div class="min-w-0 space-y-1">
        <div class="flex flex-wrap items-center gap-3">
          <h3
            class="text-xl font-normal text-[var(--color-ink)]"
            style="font-family: var(--font-display)"
          >
            {{ product.name }}
          </h3>
          <span
            :class="
              cn(
                'border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.1em]',
                getProductStockTone()
              )
            "
            style="font-family: var(--font-mono)"
          >
            {{ product.stock }} in stock
          </span>
        </div>
        <p class="text-sm text-[var(--color-ink-2)]" style="line-height: 1.5">
          {{ product.description }}
        </p>
        <p class="font-mono text-xs font-semibold text-[var(--color-ink)]">
          {{ formatPrice(product.price) }}
        </p>
        <p
          v-if="adjustmentError"
          class="text-xs italic text-danger"
          style="font-family: var(--font-display)"
        >
          {{ adjustmentError }}
        </p>
        <p
          v-if="uploadError"
          class="text-xs italic text-danger"
          style="font-family: var(--font-display)"
        >
          {{ uploadError }}
        </p>
      </div>
    </div>

    <!-- Actions Toolbar -->
    <div class="flex flex-wrap items-center gap-4 lg:justify-end">
      <form @submit.prevent="adjustStock" class="flex items-center gap-2">
        <input
          type="number"
          min="0"
          class="h-9 w-20 rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-2 font-mono text-sm text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0"
          v-model="stockForm.field('stock').value.value"
        />
        <Button
          type="submit"
          size="sm"
          variant="secondary"
          class="rounded-none font-mono text-xs uppercase tracking-[0.1em]"
          :disabled="isAdjusting"
        >
          {{ isAdjusting ? "Saving..." : "Update Stock" }}
        </Button>
      </form>

      <div class="flex flex-col gap-1">
        <Button
          :data-testid="`merchant-upload-media-${product.id}`"
          size="sm"
          variant="secondary"
          class="rounded-none font-mono text-xs uppercase tracking-[0.1em]"
          @click="emit('requestUpload')"
          :disabled="isUploading"
        >
          {{ isUploading ? "Uploading..." : "Upload Media" }}
        </Button>
        <div v-if="isUploading" class="h-1 w-full bg-[var(--color-rule)]">
          <div
            :data-testid="`merchant-upload-progress-bar-${product.id}`"
            class="h-full bg-[var(--color-ink)] transition-all duration-300 ease-linear"
            :style="{ width: `${uploadProgress}%` }"
          ></div>
        </div>
      </div>
    </div>
  </div>
</template>
