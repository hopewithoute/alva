export function useDebounce(fn: Function, ms = 300) {
  let timeoutId: any = null;
  return (...args: any[]) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn(...args), ms);
  };
}
