<script setup lang="ts">
import { ref } from "vue";
import { useAlva } from "@/js/alva";
import type { Product } from "@/js/alva/types";
import MerchantInventoryItem from "./MerchantInventoryItem.vue";
import type { InventoryFilters } from "@/vue/features/merchant/types";
import Button from "@/vue/shared/ui/button/Button.vue";
import { useFilterQuerySync } from "@/vue/shared/useFilterQuerySync";
import { getErrorMessage } from "@/vue/utils/error";

const props = defineProps<{
  products?: Product[];
  isInventoryFiltered?: boolean;
  initialFilters?: InventoryFilters;
}>();

const alva = useAlva();

const { filters: inventory_filters, resetFilters: clearInventoryFilters } =
  useFilterQuerySync<InventoryFilters>(
    () => props.initialFilters,
    { query: "", low_stock: false },
    (filters) => ({
      inv_query: filters.query || null,
      inv_low_stock: filters.low_stock ? "true" : null
    })
  );

const mediaUpload = alva.use_upload("media", { maxFiles: 1 });
const activeUploadProductId = ref<string | null>(null);
const uploadErrors = ref<Record<string, string>>({});
const isSavingUpload = ref(false);

const handleUploadRequest = async (productId: string) => {
  if (isSavingUpload.value || mediaUpload.progress.value > 0) return;

  uploadErrors.value[productId] = "";
  activeUploadProductId.value = productId;

  const upload_request = mediaUpload.dispatch(
    async ({ primaryReference }: { primaryReference: string }) => {
      isSavingUpload.value = true;
      const result = await alva.catalog.upload_media({
        id: productId,
        media: primaryReference
      });

      if (!result.ok) {
        uploadErrors.value[productId] = result.error?.message || "Failed to upload media.";
      }

      isSavingUpload.value = false;
      return result;
    }
  );

  mediaUpload.showFilePicker();

  try {
    await upload_request;
  } catch (error: unknown) {
    uploadErrors.value[productId] = getErrorMessage(error);
  } finally {
    isSavingUpload.value = false;
    activeUploadProductId.value = null;
  }
};
</script>

<template>
  <section class="space-y-8">
    <div
      class="flex flex-col gap-6 border-b border-[var(--color-rule)] pb-6 md:flex-row md:items-end md:justify-between"
    >
      <div class="flex items-baseline gap-4">
        <h2
          class="text-2xl font-normal text-[var(--color-ink)]"
          style="font-family: var(--font-display)"
        >
          Inventory
        </h2>
        <span class="text-xs text-[var(--color-ink-2)]" style="font-family: var(--font-mono)">
          {{ props.products?.length || 0 }} total
        </span>
      </div>

      <div class="flex flex-col gap-4 sm:flex-row sm:items-end">
        <input
          v-model="inventory_filters.query"
          data-testid="merchant-inventory-query"
          type="text"
          placeholder="Search name or description..."
          class="h-8 w-56 rounded-none border-0 border-b border-[var(--color-rule-2)] bg-transparent px-0 text-sm font-normal text-[var(--color-ink)] focus:border-[var(--color-ink)] focus:outline-none focus:ring-0"
        />

        <label
          class="flex cursor-pointer items-center gap-2 text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink-2)]"
          style="font-family: var(--font-mono)"
        >
          <input
            v-model="inventory_filters.low_stock"
            type="checkbox"
            class="h-3.5 w-3.5 rounded-none border-[var(--color-rule)] text-[var(--color-ink)] focus:ring-0"
          />
          Low stock only
        </label>

        <Button
          variant="secondary"
          size="sm"
          class="rounded-none font-mono text-xs uppercase tracking-[0.1em]"
          :disabled="!isInventoryFiltered"
          @click="clearInventoryFilters"
        >
          Reset
        </Button>
      </div>
    </div>

    <div
      v-if="!props.products?.length"
      class="py-12 text-sm italic text-[var(--color-ink-2)]"
      style="font-family: var(--font-display)"
    >
      No products match your current filters.
    </div>
    <div v-else class="grid grid-cols-1 gap-6 xl:grid-cols-2">
      <MerchantInventoryItem
        v-for="product in props.products || []"
        :key="product.id"
        :product="product"
        :is-uploading="
          activeUploadProductId === product.id && (isSavingUpload || mediaUpload.progress.value > 0)
        "
        :upload-progress="activeUploadProductId === product.id ? mediaUpload.progress.value : 0"
        :upload-error="uploadErrors[product.id]"
        @request-upload="handleUploadRequest(product.id)"
      />
    </div>
  </section>
</template>
