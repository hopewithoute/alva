/**
 * Formats currency amount in cents to USD format string (e.g. 1500 -> "$15.00").
 */
export function formatPrice(cents: number | null | undefined): string {
  if (cents == null || isNaN(cents)) return "$0.00";
  return `$${(cents / 100).toFixed(2)}`;
}

/**
 * Formats ISO date string to localized date-time string (e.g. "2026-07-23T18:00:00Z" -> "7/23/2026, 6:00:00 PM").
 */
export function formatDateTime(value?: string | null): string {
  if (!value) return "n/a";
  const date = new Date(value);
  if (isNaN(date.getTime())) return "n/a";
  return date.toLocaleString();
}
