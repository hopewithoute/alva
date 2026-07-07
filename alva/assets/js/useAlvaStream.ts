import { ref, onUnmounted, computed, getCurrentInstance } from "vue";
import { useAlvaSubscriptions } from "./useAlvaSubscriptions";
import type { AlvaSubscriptionDef } from "./useAlvaSubscriptions";

export function useAlvaStream<
    Subs extends Record<string, AlvaSubscriptionDef> = any,
    S extends keyof Subs = keyof Subs
>(
    name: S,
    input: Subs[S]["input"]
) {
    const subs = useAlvaSubscriptions<Subs>();
    const isLoading = ref(false);
    const error = ref<any>(null);

    const instance = getCurrentInstance();
    const streamPropData = instance?.props[name as string];

    // If streamPropData has any keys, it means it's been populated by LiveView eager streams.
    // An uninitialized LiveView stream might be undefined.
    const hasEagerData = computed(() => {
        return streamPropData !== undefined;
    });

    if (!hasEagerData.value) {
        isLoading.value = true;
        subs.activate(name, input)
            .then((result) => {
                if (!result.ok) {
                    error.value = result.error;
                }
            })
            .catch((e) => {
                error.value = e;
            })
            .finally(() => {
                isLoading.value = false;
            });
    }

    onUnmounted(() => {
        subs.deactivate(name, input);
    });

    const loadMore = (params: Subs[S]["input"]) => {
        isLoading.value = true;
        return subs.loadMore(name, params)
            .then((result) => {
                if (!result.ok) {
                    error.value = result.error;
                }
                return result;
            })
            .catch((e) => {
                error.value = e;
                throw e;
            })
            .finally(() => {
                isLoading.value = false;
            });
    };

    return { isLoading, error, loadMore };
}
