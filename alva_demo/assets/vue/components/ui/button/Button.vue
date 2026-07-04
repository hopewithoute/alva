<script setup lang="ts">
import { cn } from "@/vue/lib/utils"

withDefaults(
  defineProps<{
    variant?: "primary" | "secondary"
    class?: string
  }>(),
  {
    variant: "primary",
    class: "",
  },
)
</script>

<template>
  <button
    :class="
      cn(
        'inline-flex h-9 items-center justify-center rounded-md px-4 text-sm font-medium transition-colors',
        variant === 'primary'
          ? 'bg-zinc-950 text-white hover:bg-zinc-800'
          : 'border border-zinc-300 bg-white text-zinc-950 hover:bg-zinc-100',
        $props.class,
      )
    "
  >
    <slot />
  </button>
</template>
