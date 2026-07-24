import { reactive, watch } from "vue";
import { useDebounce } from "@/vue/utils/debounce";
import { useRouteQueryPatch } from "@/vue/shared/useRouteQueryPatch";

export function useFilterQuerySync<T extends object>(
  initialFiltersGetter: () => T | undefined,
  defaultFilters: T,
  toQueryParams: (filters: T) => Record<string, string | null>,
  debounceMs = 300
) {
  const { patchQuery } = useRouteQueryPatch();
  /* eslint-disable-next-line @typescript-eslint/consistent-type-assertions */
  const filters = reactive({ ...defaultFilters }) as T;

  watch(
    initialFiltersGetter,
    (newVal) => {
      if (!newVal) return;
      Object.assign(filters, newVal);
    },
    { deep: true, immediate: true }
  );

  const debouncedPatch = useDebounce((updatedFilters: T) => {
    patchQuery(toQueryParams(updatedFilters));
  }, debounceMs);

  watch(
    filters,
    (updatedFilters) => {
      if (updatedFilters && typeof updatedFilters === "object") {
        /* eslint-disable-next-line @typescript-eslint/consistent-type-assertions */
        debouncedPatch(updatedFilters as T);
      }
    },
    { deep: true }
  );

  const resetFilters = () => {
    Object.assign(filters, defaultFilters);
  };

  return {
    filters,
    resetFilters
  };
}
