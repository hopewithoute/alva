export const getStatusColor = (status: string) => {
  switch (status) {
    case 'new': return 'bg-blue-50 text-blue-700 border-blue-200';
    case 'processing': return 'bg-amber-50 text-amber-700 border-amber-200';
    case 'fulfilled': return 'bg-emerald-50 text-emerald-700 border-emerald-200';
    default: return 'bg-zinc-50 text-zinc-700 border-zinc-200';
  }
};
