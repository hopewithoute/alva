<script setup lang="ts">
import type { Order } from "@/js/alva/types";
import { Badge } from "@/vue/components/ui/badge";

type BadgeVariant = "default" | "secondary" | "outline";

const BADGE_VARIANT_MAP: Record<Order["lifecycle_status"], BadgeVariant> = {
  new: "default",
  processing: "secondary",
  fulfilled: "outline"
};

defineProps<{
  status: Order["lifecycle_status"];
}>();
</script>

<template>
  <Badge
    :variant="BADGE_VARIANT_MAP[status] ?? 'outline'"
    class="px-3 py-1 text-sm font-medium capitalize"
  >
    {{ status }}
  </Badge>
</template>
