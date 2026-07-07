import { reactive, watch, type Ref } from "vue";

/**
 * Creates a local reactive copy of remote filters that syncs when the remote filters change.
 * This eliminates duplicated boilerplate in components for syncing server state to local state.
 * 
 * @param remoteFiltersRef The ref containing the latest filters from the server/parent.
 * @param defaultValues The default values to use if a key is missing or remote filters are empty.
 * @returns A reactive object containing the local filters.
 */
export function useSyncedFilters<T extends Record<string, any>>(
  remoteFiltersRef: Ref<T | undefined> | undefined,
  defaultValues: T
): T {
  const localFilters = reactive({ ...defaultValues }) as T;

  watch(
    () => remoteFiltersRef?.value,
    (newVal) => {
      if (!newVal) return;
      for (const key in defaultValues) {
        if (Object.prototype.hasOwnProperty.call(defaultValues, key)) {
          localFilters[key] = (newVal[key] ?? defaultValues[key]) as any;
        }
      }
    },
    { deep: true, immediate: true }
  );

  return localFilters;
}
