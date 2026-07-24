<script setup lang="ts">
import { cn } from "@/vue/lib/utils";
import { cva, type VariantProps } from "class-variance-authority";

const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md text-sm font-medium transition-all duration-150 ease-out active:scale-[0.97] disabled:cursor-not-allowed disabled:opacity-70",
  {
    variants: {
      variant: {
        primary:
          "bg-[var(--color-ink)] text-[var(--color-paper)] hover:opacity-90 disabled:bg-[var(--color-rule)] disabled:text-[var(--color-ink-2)]",
        secondary:
          "border border-[var(--color-rule)] bg-[var(--color-paper)] text-[var(--color-ink)] hover:bg-[var(--color-rule)] disabled:border-[var(--color-rule)] disabled:bg-[var(--color-rule)] disabled:text-[var(--color-ink-2)]",
        specimen:
          "shrink-0 gap-2 rounded-none border border-[var(--color-ink)] bg-transparent px-5 py-3 font-mono text-xs font-semibold uppercase tracking-[0.1em] text-[var(--color-ink)] transition-colors hover:bg-[var(--color-ink)] hover:text-[var(--color-paper)]"
      },
      size: {
        sm: "h-8 px-3 text-xs",
        md: "h-9 px-4"
      }
    },
    defaultVariants: {
      variant: "primary",
      size: "md"
    }
  }
);

type ButtonVariants = VariantProps<typeof buttonVariants>;

defineOptions({
  inheritAttrs: false
});

const props = withDefaults(
  defineProps<{
    variant?: ButtonVariants["variant"];
    size?: ButtonVariants["size"];
    disabled?: boolean;
    class?: string;
  }>(),
  {
    variant: "primary",
    size: "md",
    disabled: false,
    class: ""
  }
);
</script>

<template>
  <button
    v-bind="$attrs"
    :disabled="disabled"
    :class="cn(buttonVariants({ variant, size }), props.class)"
  >
    <slot />
  </button>
</template>
