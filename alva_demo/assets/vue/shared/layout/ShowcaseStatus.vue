<script setup lang="ts">
defineProps<{
  surface: "entry" | "customer" | "merchant";
}>();
</script>

<template>
  <div class="space-y-3" data-testid="showcase-status">
    <p class="text-sm font-medium text-[var(--color-ink-2)]">LiveVue shell</p>
    <p class="text-2xl font-semibold text-[var(--color-ink)]">Ready for {{ surface }}</p>
    <p class="text-sm text-[var(--color-ink-2)]">
      This component is rendered through the Vite component registry.
    </p>
  </div>
</template>
