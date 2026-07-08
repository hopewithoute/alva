import { ref } from "vue";
import { useLiveVue } from "live_vue";
import type { AlvaError, AlvaResult } from "./useAlvaApi";

type PageEventContract = {
    input: any;
    output: AlvaResult<any>;
};

function transportError(event: string, reason: unknown): AlvaError {
    const fallbackMessage = `Page event "${event}" failed before a reply was received.`;

    if (reason && typeof reason === "object" && "message" in reason) {
        const message = (reason as { message?: unknown }).message;

        if (typeof message === "string" && message.trim() !== "") {
            return { type: "unknown", message };
        }
    }

    if (typeof reason === "string" && reason.trim() !== "") {
        return { type: "unknown", message: reason };
    }

    return { type: "unknown", message: fallbackMessage };
}

function extractReply(result: unknown): AlvaResult<any> | null {
    if (result && typeof result === "object" && "reply" in result) {
        return extractReply((result as { reply?: unknown }).reply);
    }

    if (
        result &&
        typeof result === "object" &&
        "ok" in result &&
        typeof (result as { ok?: unknown }).ok === "boolean"
    ) {
        return result as AlvaResult<any>;
    }

    return null;
}

export function usePageEvent<
    Events extends Record<string, PageEventContract>,
    E extends keyof Events
>(event: E) {
    const live = useLiveVue();
    const isLoading = ref(false);
    const error = ref<AlvaError | null>(null);

    const call = async (
        params: Events[E]["input"] = {} as Events[E]["input"]
    ): Promise<Events[E]["output"]> => {
        isLoading.value = true;
        error.value = null;

        try {
            const rawResult = await live.pushEvent(event as string, params);
            const reply = extractReply(rawResult);

            if (!reply) {
                const structuredError = transportError(event as string, null);
                error.value = structuredError;

                return {
                    ok: false,
                    error: structuredError,
                } as Events[E]["output"];
            }

            if (reply.ok === false && reply.error) {
                error.value = reply.error;
            }

            return reply as Events[E]["output"];
        } catch (reason) {
            const structuredError = transportError(event as string, reason);
            error.value = structuredError;

            return {
                ok: false,
                error: structuredError,
            } as Events[E]["output"];
        } finally {
            isLoading.value = false;
        }
    };

    return { call, isLoading, error };
}
