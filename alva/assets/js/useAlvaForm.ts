import { ref, reactive, watch, onScopeDispose, getCurrentScope } from "vue";
import type { AlvaResult } from "./useAlvaApi";

export interface AlvaFormOptions<FormValues, EventKeys> {
    initialValues: FormValues;
    validateEvent?: EventKeys;
    debounceMs?: number;
    uploads?: Record<string, { getFileReferences: () => string[] }>;
    onOptimisticSubmit?: (formData: FormValues) => (() => void) | void;
}

export function useAlvaForm<
    Events extends Record<string, { input: any; output: any }>,
    SubmitEventKey extends keyof Events,
    FormValues = Events[SubmitEventKey]["input"],
>(
    api: {
        call: <K extends keyof Events>(
            event: K,
            params?: Events[K]["input"],
        ) => Promise<AlvaResult>;
    },
    submitEvent: SubmitEventKey,
    options: AlvaFormOptions<FormValues, keyof Events>,
) {
    const values = reactive({ ...options.initialValues } as any) as FormValues;
    const errors = ref<Record<string, string[]>>({});
    const loading = ref(false);
    const isValidating = ref(false);

    // Use a strict type for the cache instead of any
    const validationCache = new Map<string, AlvaResult>();

    if (getCurrentScope()) {
        onScopeDispose(() => {
            validationCache.clear();
        });
    }

    const applyErrors = (result: AlvaResult) => {
        if (!result.ok && result.error?.type === "validation") {
            errors.value = result.error.fields || {};
        } else if (result.ok) {
            errors.value = {};
        }
    };

    let submitCounter = 0;
    let validateCounter = 0;
    let timeout: ReturnType<typeof setTimeout>;
    let pendingResolve: ((val: AlvaResult) => void) | null = null;

    const submit = async (): Promise<AlvaResult> => {
        submitCounter++;
        const currentSubmit = submitCounter;

        // Cancel any pending validations to prevent race conditions
        validateCounter++; // Ensure any in-flight validation resolves without applying state
        clearTimeout(timeout);
        isValidating.value = false;
        if (pendingResolve) {
            pendingResolve({
                ok: false,
                error: { type: "cancelled", message: "Submit started" },
            });
            pendingResolve = null;
        }

        loading.value = true;
        errors.value = {};

        const payload = { ...values } as Record<string, any>;
        if (options.uploads) {
            for (const [key, upload] of Object.entries(options.uploads)) {
                payload[key] = upload.getFileReferences();
            }
        }

        let rollbackFn: (() => void) | void = undefined;
        if (options.onOptimisticSubmit) {
            rollbackFn = options.onOptimisticSubmit(payload as FormValues);
        }

        let result: AlvaResult;
        try {
            result = await api.call(
                submitEvent,
                payload as Events[SubmitEventKey]["input"],
            );
        } catch (e) {
            if (rollbackFn) {
                rollbackFn();
            }
            if (currentSubmit === submitCounter) {
                loading.value = false;
            }
            throw e;
        }

        if (!result.ok && rollbackFn) {
            rollbackFn();
        }

        // Only apply if another submit hasn't superseded this one
        if (currentSubmit === submitCounter) {
            applyErrors(result);
            loading.value = false;
        }

        return result;
    };

    const validate = async (): Promise<AlvaResult> => {
        if (!options.validateEvent) return { ok: true, data: {} };

        validateCounter++;
        const currentValidation = validateCounter;

        clearTimeout(timeout);

        // Resolve the previous hanging promise
        if (pendingResolve) {
            pendingResolve({
                ok: false,
                error: { type: "cancelled", message: "Superseded" },
            });
        }

        isValidating.value = true;

        return new Promise((resolve) => {
            pendingResolve = resolve;
            timeout = setTimeout(async () => {
                const cacheKey = JSON.stringify(values);
                let result = validationCache.get(cacheKey);

                if (!result) {
                    try {
                        result = await api.call(
                            options.validateEvent!,
                            values as any,
                        );
                        validationCache.set(cacheKey, result);
                    } catch (error: any) {
                        result = { ok: false, error: { type: "unknown", message: error.message || String(error) } };
                    }
                }

                // Only apply if this is still the most recent validation and no submit has occurred
                if (currentValidation === validateCounter && !loading.value) {
                    applyErrors(result!);
                    isValidating.value = false;
                }

                if (pendingResolve === resolve) {
                    pendingResolve = null;
                }
                resolve(result!);
            }, options.debounceMs || 300);
        });
    };

    if (options.validateEvent) {
        watch(
            values as any,
            () => {
                validate();
            },
            { deep: true },
        );
    }

    const reset = () => {
        Object.assign(values as any, options.initialValues);
        errors.value = {};
    };

    return {
        values,
        errors,
        loading,
        isValidating,
        submit,
        validate,
        reset,
    };
}
