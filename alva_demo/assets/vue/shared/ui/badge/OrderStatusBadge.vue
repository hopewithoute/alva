<script setup lang="ts">
import { getStatusColor } from "../../utils/ui";
import type { Order } from "../../../../js/alva/types";

defineProps<{
  status: Order["lifecycle_status"];
}>();
</script>

<template>
  <div :class="['rounded-full border px-3 py-1 text-sm font-medium capitalize', getStatusColor(status)]">
    {{ status }}
  </div>
</template>
