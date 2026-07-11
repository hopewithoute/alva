export const getStatusColor = (status: string) => {
  switch (status) {
    case 'new': return 'bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950 dark:text-blue-300 dark:border-blue-800';
    case 'processing': return 'bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950 dark:text-amber-300 dark:border-amber-800';
    case 'fulfilled': return 'bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950 dark:text-emerald-300 dark:border-emerald-800';
    default: return 'bg-[var(--color-rule)] text-[var(--color-ink)] border-[var(--color-rule-2)]';
  }
};
