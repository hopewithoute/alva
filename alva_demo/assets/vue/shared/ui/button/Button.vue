<script setup lang="ts">
import { cn } from "@/vue/lib/utils"

defineOptions({
  inheritAttrs: false,
})

withDefaults(
  defineProps<{
    variant?: "primary" | "secondary"
    size?: "sm" | "md"
    disabled?: boolean
    class?: string
  }>(),
  {
    variant: "primary",
    size: "md",
    disabled: false,
    class: "",
  },
)
</script>

<template>
  <button
    v-bind="$attrs"
    :disabled="disabled"
    :class="
      cn(
        'inline-flex h-9 items-center justify-center rounded-md px-4 text-sm font-medium transition-colors',
        size === 'sm' ? 'h-8 px-3 text-xs' : '',
        variant === 'primary'
          ? 'bg-zinc-950 text-white hover:bg-zinc-800 disabled:bg-zinc-300 disabled:text-zinc-500'
          : 'border border-zinc-300 bg-white text-zinc-950 hover:bg-zinc-100 disabled:border-zinc-200 disabled:bg-zinc-100 disabled:text-zinc-400',
        'disabled:cursor-not-allowed disabled:opacity-70',
        $props.class,
      )
    "
  >
    <slot />
  </button>
</template>
