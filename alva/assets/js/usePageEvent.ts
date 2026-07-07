import { ref } from "vue";
import { useLiveVue } from "live_vue";
import type { AlvaResult } from "./useAlvaApi";

export function usePageEvent<
    Events extends Record<string, { input: any; output: any }>,
    E extends keyof Events
>(event: E) {
    const live = useLiveVue();
    const isLoading = ref(false);
    const error = ref<{ message?: string } | null>(null);

    const call = async (
        params: Events[E]["input"] = {} as Events[E]["input"]
    ): Promise<Events[E]["output"]> => {
        isLoading.value = true;
        error.value = null;
        
        return new Promise((resolve) => {
            live.pushEvent(event as string, params, (reply: any) => {
                isLoading.value = false;
                if (reply?.ok === false && reply?.error) {
                    error.value = reply.error;
                }
                resolve(reply);
            });
        });
    };

    return { call, isLoading, error };
}
