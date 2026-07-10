<script setup lang="ts">
import { ref, computed } from "vue";
import { useAlva } from "../../../js/alva";
import type { Product } from "../../../js/alva/types";
import Button from "../../shared/ui/button/Button.vue";

const props = defineProps<{
  product: Product;
}>();

const alva = useAlva();

const stockForm = alva.catalog.use_adjust_stock_form({
  initialValues: {
    id: props.product.id,
    stock: props.product.stock,
  }
});

const isAdjusting = ref(false);
const adjustmentError = ref<string | null>(null);

const adjustStock = async () => {
  if ((stockForm.field('stock').value.value ?? 0) < 0 || isAdjusting.value) return;

  isAdjusting.value = true;
  adjustmentError.value = null;

  try {
    const result = await stockForm.submit();

    if (!result.ok) {
      adjustmentError.value = result.error?.message || "Failed to update stock.";
    }
  } catch (error: any) {
    adjustmentError.value = error.message || "Failed to update stock.";
  } finally {
    isAdjusting.value = false;
  }
};

const mediaUpload = alva.use_upload("media", { maxFiles: 1 });
const isSavingUpload = ref(false);
const uploadError = ref<string | null>(null);
const isUploading = computed(() => isSavingUpload.value || mediaUpload.progress.value > 0);

const triggerMediaUpload = async () => {
  if (isUploading.value) return;
  uploadError.value = null;

  const upload_request = mediaUpload.dispatch(async ({ primaryReference }: { primaryReference: string }) => {
    isSavingUpload.value = true;

    const result = await alva.catalog.upload_media({
      id: props.product.id,
      media: primaryReference,
    });

    if (!result.ok) {
      uploadError.value = result.error?.message || "Failed to upload media.";
    }

    isSavingUpload.value = false;
    return result;
  });

  mediaUpload.showFilePicker();

  try {
    await upload_request;
  } finally {
    isSavingUpload.value = false;
  }
};

const getProductStockTone = () => {
  if (props.product.stock <= 0) return "bg-red-50 text-red-700 border-red-200";
  if (props.product.stock <= 25) return "bg-amber-50 text-amber-700 border-amber-200";
  return "bg-emerald-50 text-emerald-700 border-emerald-200";
};

const formatPrice = (cents: number) => `$${(cents / 100).toFixed(2)}`;
</script>

<template>
  <div class="flex flex-col gap-4 rounded-lg border border-zinc-200 p-4 sm:flex-row sm:items-center sm:justify-between">
    <div class="flex min-w-0 items-center gap-4">
      <div v-if="product.media_reference" class="h-12 w-12 shrink-0 overflow-hidden rounded border border-zinc-200 bg-zinc-100">
        <img :src="`/images/${product.media_reference}`" class="h-full w-full object-cover" />
      </div>
      <div v-else class="flex h-12 w-12 shrink-0 items-center justify-center rounded border border-zinc-200 bg-zinc-100 text-xs text-zinc-400">
        No img
      </div>

      <div class="min-w-0">
        <div class="flex flex-wrap items-center gap-2">
          <p class="font-medium text-zinc-900">{{ product.name }}</p>
          <span :class="['inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-medium', getProductStockTone()]">
            {{ product.stock }} in stock
          </span>
        </div>
        <p class="mt-1 text-sm text-zinc-500">{{ product.description }}</p>
        <p class="mt-2 text-xs font-medium text-zinc-500">{{ formatPrice(product.price) }}</p>
        <p v-if="adjustmentError" class="mt-2 text-xs text-red-600">{{ adjustmentError }}</p>
        <p v-if="uploadError" class="mt-2 text-xs text-red-600">{{ uploadError }}</p>
      </div>
    </div>

    <div class="flex flex-wrap items-center gap-3">
      <form @submit.prevent="adjustStock" class="flex items-center gap-2">
        <input type="number" min="0" class="w-24 rounded-md border border-zinc-300 px-3 py-1.5 text-sm" v-model="stockForm.field('stock').value.value" />
        <Button type="submit" size="sm" variant="secondary" class="min-w-[104px]" :disabled="isAdjusting">
          {{ isAdjusting ? "Saving..." : "Update Stock" }}
        </Button>
      </form>

      <div class="flex w-28 flex-col gap-1">
        <Button :data-testid="`merchant-upload-media-${product.id}`" size="sm" variant="secondary" class="min-w-[112px]" @click="triggerMediaUpload" :disabled="isUploading">
          {{ isUploading ? "Uploading..." : "Upload Media" }}
        </Button>
        <div v-if="isUploading" class="h-1.5 w-full overflow-hidden rounded-full bg-zinc-200">
          <div :data-testid="`merchant-upload-progress-bar-${product.id}`" class="h-full bg-blue-600 transition-all duration-300" :style="{ width: `${mediaUpload.progress.value}%` }"></div>
        </div>
      </div>
    </div>
  </div>
</template>
