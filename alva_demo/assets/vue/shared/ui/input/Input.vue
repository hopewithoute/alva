<script setup lang="ts">
import { cn } from "@/vue/lib/utils";
import { cva, type VariantProps } from "class-variance-authority";

const inputVariants = cva(
  "w-full bg-transparent text-sm text-[var(--color-ink)] transition-colors focus:outline-none focus:ring-0 disabled:cursor-not-allowed disabled:opacity-50",
  {
    variants: {
      variant: {
        underline:
          "rounded-none border-0 border-b border-[var(--color-rule-2)] px-0 py-2 font-mono focus:border-[var(--color-ink)]",
        outline:
          "rounded-none border border-[var(--color-rule-2)] p-3 focus:border-[var(--color-ink)]"
      }
    },
    defaultVariants: {
      variant: "underline"
    }
  }
);

type InputVariants = VariantProps<typeof inputVariants>;

defineOptions({
  inheritAttrs: false
});

const props = withDefaults(
  defineProps<{
    modelValue?: string | number;
    variant?: InputVariants["variant"];
    placeholder?: string;
    type?: string;
    disabled?: boolean;
    class?: string;
  }>(),
  {
    modelValue: "",
    variant: "underline",
    type: "text",
    disabled: false,
    class: ""
  }
);

const emit = defineEmits<{
  (e: "update:modelValue", value: string): void;
}>();

const handleInput = (event: Event) => {
  const target = event.target;
  if (target && "value" in target && typeof target.value === "string") {
    emit("update:modelValue", target.value);
  }
};
</script>

<template>
  <input
    v-bind="$attrs"
    :type="type"
    :value="modelValue"
    :placeholder="placeholder"
    :disabled="disabled"
    :class="cn(inputVariants({ variant }), props.class)"
    @input="handleInput"
  />
</template>
