import { cva } from "class-variance-authority";

export const statusBadgeVariants = cva(
  "border px-2 py-0.5 font-mono text-[10px] font-semibold uppercase tracking-[0.1em]",
  {
    variants: {
      status: {
        new: "border-danger-border bg-danger-surface text-danger",
        processing: "border-warning-border bg-warning-surface text-warning",
        fulfilled: "border-success-border bg-success-surface text-success",
        default: "border-[var(--color-rule)] bg-[var(--color-paper-2)] text-[var(--color-ink-2)]"
      }
    },
    defaultVariants: {
      status: "default"
    }
  }
);

export const eyebrowVariants = cva("font-semibold uppercase text-[var(--color-ink-2)]", {
  variants: {
    size: {
      sm: "text-[10px] tracking-[0.15em]",
      md: "text-xs tracking-[0.2em]"
    }
  },
  defaultVariants: {
    size: "md"
  }
});

export const getStatusColor = (status: string) => {
  switch (status) {
    case "new":
      return "border-danger-border bg-danger-surface text-danger";
    case "processing":
      return "border-warning-border bg-warning-surface text-warning";
    case "fulfilled":
      return "border-success-border bg-success-surface text-success";
    default:
      return "border-[var(--color-rule)] bg-[var(--color-paper-2)] text-[var(--color-ink-2)]";
  }
};
