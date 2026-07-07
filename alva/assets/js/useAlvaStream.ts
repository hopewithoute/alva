import { ref, onUnmounted, computed } from "vue";
import { useAlvaSubscriptions } from "./useAlvaSubscriptions";
import type { AlvaSubscriptionDef } from "./useAlvaSubscriptions";

export function useAlvaStream<
    Subs extends Record<string, AlvaSubscriptionDef> = any,
    S extends keyof Subs = keyof Subs
>(
    name: S,
    input: Subs[S]["input"],
    streamPropData?: any // The data passed from LiveVue props for this stream
) {
    const subs = useAlvaSubscriptions<Subs>();
    const isLoading = ref(false);
    const error = ref<any>(null);

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

    return { isLoading, error };
}
