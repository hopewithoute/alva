import type { VariantProps } from "class-variance-authority";
import { cva } from "class-variance-authority";

export { default as Badge } from "./Badge.vue";

export const badgeVariants = cva(
  "inline-flex items-center gap-1 rounded-none border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.1em] transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
  {
    variants: {
      variant: {
        default: "hover:bg-primary/80 border-transparent bg-primary text-primary-foreground shadow",
        secondary:
          "hover:bg-secondary/80 border-transparent bg-secondary text-secondary-foreground",
        destructive:
          "hover:bg-destructive/80 border-transparent bg-destructive text-destructive-foreground shadow",
        outline: "text-foreground"
      }
    },
    defaultVariants: {
      variant: "default"
    }
  }
);

export type BadgeVariants = VariantProps<typeof badgeVariants>;
