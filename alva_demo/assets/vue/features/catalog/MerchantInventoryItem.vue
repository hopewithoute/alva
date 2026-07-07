<script setup lang="ts">
import { ref, computed } from "vue";
import { usePageEvent, ashUpload } from "alva";
import type { AlvaEvents } from "../../js/alva/events";
import type { Product } from "../../js/alva/types";
import Button from "../../shared/ui/button/Button.vue";

const props = defineProps<{
  product: Product;
}>();

const stockInput = ref(props.product.stock);

const adjustStockEvent = usePageEvent<AlvaEvents, "catalog.adjust_stock">("catalog.adjust_stock");
const isAdjusting = computed(() => adjustStockEvent.isLoading.value);
const adjustmentError = computed(() => adjustStockEvent.error.value?.message || null);

const adjustStock = async () => {
  if (stockInput.value < 0 || isAdjusting.value) return;
  await adjustStockEvent.call({ id: props.product.id, stock: stockInput.value });
};

const mediaUpload = ashUpload("media", { maxFiles: 1 });
const uploadMediaEvent = usePageEvent<AlvaEvents, "catalog.upload_media">("catalog.upload_media");
const isUploading = computed(() => uploadMediaEvent.isLoading.value || mediaUpload.progress.value > 0);
const uploadError = computed(() => uploadMediaEvent.error.value?.message || null);

const triggerMediaUpload = async () => {
  if (isUploading.value) return;
  
  const upload_request = mediaUpload.dispatch(async ({ primaryReference }) => {
    return await uploadMediaEvent.call({
      id: props.product.id,
      media: primaryReference,
    });
  });
  
  mediaUpload.showFilePicker();
  
  await upload_request;
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
      <input type="number" min="0" class="w-24 rounded-md border border-zinc-300 px-3 py-1.5 text-sm" v-model="stockInput" />
      <Button size="sm" variant="secondary" class="min-w-[104px]" @click="adjustStock" :disabled="isAdjusting">
        {{ isAdjusting ? "Saving..." : "Update Stock" }}
      </Button>

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
