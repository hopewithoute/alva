<script setup lang="ts">
defineProps<{
  surface: "entry" | "customer" | "merchant"
}>()
</script>

<template>
  <div class="space-y-3" data-testid="showcase-status">
    <p class="text-sm font-medium text-zinc-500">LiveVue shell</p>
    <p class="text-2xl font-semibold text-zinc-950">Ready for {{ surface }}</p>
    <p class="text-sm text-zinc-600">
      This component is rendered through the Vite component registry.
    </p>
  </div>
</template>
