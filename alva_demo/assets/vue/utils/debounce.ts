export function useDebounce<Args extends unknown[]>(
  fn: (...args: Args) => void,
  ms = 300
): (...args: Args) => void {
  let timeoutId: ReturnType<typeof setTimeout> | null = null;
  return (...args: Args) => {
    if (timeoutId !== null) {
      clearTimeout(timeoutId);
    }
    timeoutId = setTimeout(() => {
      fn(...args);
    }, ms);
  };
}
