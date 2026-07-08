import { useLiveVue, useLiveEvent } from "live_vue";

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
 * `on` remains available as a compatibility helper, but `useAlvaSignal`
 * is the preferred V2 component-level signal lifecycle wrapper.
 */
export function useAlvaApi<
    Events extends Record<string, { input: any; output: AlvaResult<any> }> =
        any,
    SignalEvents extends Record<string, any> = any,
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

    /**
     * Compatibility helper for semantic Signal delivery (e.g., async progress, toasts).
     * Prefer `useAlvaSignal` for component-scoped subscriptions so activation and
     * cleanup stay aligned with the V2 typed subscription lifecycle.
     */
    const on = <E extends keyof SignalEvents>(
        event: E,
        callback: (payload: SignalEvents[E]) => void,
    ): void => {
        useLiveEvent<SignalEvents[E]>(event as string, callback);
    };

    return {
        call,
        on,
    };
}
