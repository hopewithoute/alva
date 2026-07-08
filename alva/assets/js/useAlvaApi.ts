import { useLiveVue } from "live_vue";

export type AlvaErrorType =
    | "validation"
    | "forbidden"
    | "not_found"
    | "conflict"
    | "stale"
    | "cancelled"
    | "unknown";

export type AlvaError = {
    type: AlvaErrorType;
    message: string;
    code?: string;
    fields?: Record<string, string[]>;
    meta?: unknown;
};

export type AlvaResult<T = any> =
    | { ok: true; data: T; meta?: Record<string, unknown> }
    | { ok: false; error: AlvaError };

export interface AlvaApiConfig {
    onError?: (error: AlvaError, event: string) => void;
    onSuccess?: (data: unknown, event: string) => void;
}

export interface AlvaCallOptions {
    optimisticUpdate?: boolean;
    // Future options for optimistic UI, caching, etc. can be added here
}

/**
 * Provides the primary client interface for Alva.
 * It offers request/reply command execution via `call`.
 */
export function useAlvaApi<
    Events extends Record<string, { input: any; output: AlvaResult<any> }> =
        any,
>(config?: AlvaApiConfig) {
    const live = useLiveVue();

    /**
     * Execute a remote event (mutation or ad hoc read) and return an immediate promise.
     */
    const call = <E extends keyof Events>(
        event: E,
        payload: Events[E]["input"],
        options?: AlvaCallOptions,
    ): Promise<Events[E]["output"]> => {
        return new Promise((resolve) => {
            // Opt-in pathway for optimistic UI
            if (options?.optimisticUpdate) {
                // Implementation for optimistic UI would intercept here
            }

            live.pushEvent(event as string, payload, (reply: any) => {
                if (reply.ok) {
                    config?.onSuccess?.(reply.data, event as string);
                    resolve(reply as Events[E]["output"]);
                } else {
                    config?.onError?.(reply.error, event as string);
                    resolve(reply as Events[E]["output"]);
                }
            });
        });
    };

    return {
        call,
    };
}
