import { ref, onMounted, Ref } from "vue";
import type { LiveError } from "./useAlvaApi";

export interface AshQueryOptions<T> {
    initialData?: T[];
    autoFetch?: boolean;
}

/**
 * `ashQuery` is designed for ad hoc command/read fetching that is not owned by a route stream.
 * It fetches data on mount (if autoFetch is true) and manages loading/error states.
 *
 * Note: For Route Collection stream props (canonical list updates via server),
 * rely on LiveView stream diffs instead of ashQuery. `ashQuery` does not automatically
 * reconcile stream events (insert/delete).
 */
export function ashQuery<
    Events extends Record<string, { input: any; output: any }>,
    E extends keyof Events,
    T = Events[E]["output"] extends { data: infer D }
        ? D extends any[]
            ? D[number]
            : D
        : any,
>(
    api: {
        call: (event: E, params?: Events[E]["input"]) => Promise<any>;
    },
    event: E,
    params?: Events[E]["input"],
    options: AshQueryOptions<T> = {},
) {
    const data = ref(options.initialData || []) as Ref<T[]>;
    const loading = ref(!options.initialData && options.autoFetch !== false);
    const error = ref<LiveError | null>(null);
    const meta = ref<Record<string, unknown> | null>(null);

    const fetch = async () => {
        loading.value = true;
        error.value = null;
        const result = await api.call(event, params);

        if (result.ok) {
            if (!Array.isArray(result.data)) {
                console.warn(
                    `[ashQuery] Expected array response for ${String(event)}, but got ${typeof result.data}.`,
                );
            }
            data.value = result.data as unknown as T[];
            meta.value = result.meta || null;
        } else {
            error.value = result.error;
        }
        loading.value = false;
    };

    if (!options.initialData && options.autoFetch !== false) {
        onMounted(() => {
            fetch();
        });
    }

    return {
        data,
        loading,
        error,
        meta,
        fetch,
    };
}
