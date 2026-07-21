export const getStatusColor = (status: string) => {
  switch (status) {
    case 'new': return 'border-danger-border bg-danger-surface text-danger';
    case 'processing': return 'border-warning-border bg-warning-surface text-warning';
    case 'fulfilled': return 'border-success-border bg-success-surface text-success';
    default: return 'border-[var(--color-rule)] bg-[var(--color-paper-2)] text-[var(--color-ink-2)]';
  }
};
