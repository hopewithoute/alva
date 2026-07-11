<script setup lang="ts">
import type { Order } from "../../../../js/alva/types";
import { Badge } from "@/vue/components/ui/badge";

const props = defineProps<{
  status: Order["lifecycle_status"];
}>();

const getVariant = (status: string) => {
  switch (status) {
    case 'new': return 'default';
    case 'processing': return 'secondary';
    case 'fulfilled': return 'outline';
    default: return 'outline';
  }
};
</script>

<template>
  <Badge :variant="getVariant(status)" class="capitalize px-3 py-1 text-sm font-medium">
    {{ status }}
  </Badge>
</template>
