import { ref } from "vue";
import { useAlvaApi, type LiveError } from "./useAlvaApi";

export function usePageEvent<
    Events extends Record<string, { input: any; output: any }>,
    E extends keyof Events
>(event: E) {
    const api = useAlvaApi();
    const isLoading = ref(false);
    const error = ref<LiveError | null>(null);

    const call = async (payload: Events[E]["input"]): Promise<Events[E]["output"]> => {
        isLoading.value = true;
        error.value = null;
        try {
            const reply = await api.call(event as string, payload);
            if (reply && typeof reply === 'object' && 'ok' in reply && reply.ok === false) {
                error.value = reply.error as LiveError;
            }
            return reply as Events[E]["output"];
        } catch (e: any) {
            error.value = { type: "unknown", message: e.message || "Unknown error" };
            throw e;
        } finally {
            isLoading.value = false;
        }
    };

    return {
        call,
        isLoading,
        error
    };
}
