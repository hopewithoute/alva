import { ref, onUnmounted, computed, getCurrentInstance, watch, isRef } from "vue";
import { useAlvaSubscriptions } from "./useAlvaSubscriptions";
import type { AlvaSubscriptionDef } from "./useAlvaSubscriptions";

export function useAlvaStream<
    Subs extends Record<string, AlvaSubscriptionDef> = any,
    S extends keyof Subs = keyof Subs
>(
    name: S,
    input: Subs[S]["input"] | import("vue").Ref<Subs[S]["input"]> | (() => Subs[S]["input"])
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

    const getInputVal = () => {
        if (typeof input === 'function') {
            return (input as Function)();
        } else if (isRef(input)) {
            return input.value;
        } else {
            return input;
        }
    };

    let currentInputValStr = JSON.stringify(getInputVal());

    const doActivate = () => {
        const val = getInputVal();
        isLoading.value = true;
        subs.activate(name, val)
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
    };

    if (!hasEagerData.value) {
        doActivate();
    }

    watch(
        () => JSON.stringify(getInputVal()),
        (newStr, oldStr) => {
            if (newStr !== oldStr) {
                if (oldStr) {
                    subs.deactivate(name, JSON.parse(oldStr));
                }
                currentInputValStr = newStr;
                doActivate();
            }
        }
    );

    onUnmounted(() => {
        if (currentInputValStr) {
            subs.deactivate(name, JSON.parse(currentInputValStr));
        }
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
