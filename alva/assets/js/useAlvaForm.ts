import { ref, reactive, watch, onScopeDispose, getCurrentScope } from "vue";
import type { AlvaResult } from "./useAlvaApi";
import { useLiveForm, type Form, type UseLiveFormReturn } from "live_vue";

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
    FormValues extends object = Events[SubmitEventKey]["input"],
>(
    api: any, // Kept for backwards compatibility but not used directly
    submitEvent: SubmitEventKey,
    options: AlvaFormOptions<FormValues, keyof Events>,
): UseLiveFormReturn<FormValues> & { 
    submit: () => Promise<AlvaResult>; 
    validate: () => Promise<AlvaResult>;
    loading: import("vue").Ref<boolean>;
    errors: import("vue").Ref<Record<string, string[]>>;
    values: FormValues;
} {
    const pseudoForm = reactive({
        name: submitEvent as string,
        values: JSON.parse(JSON.stringify(options.initialValues)),
        errors: {},
        valid: true,
    }) as Form<FormValues>;

    const loading = ref(false);

    const liveForm = useLiveForm(pseudoForm, {
        submitEvent: submitEvent as string,
        changeEvent: options.validateEvent as string | null,
        debounceInMiliseconds: options.debounceMs || 300,
        prepareData: (data) => {
            if (options.uploads) {
                for (const [key, upload] of Object.entries(options.uploads)) {
                    data[key] = upload.getFileReferences();
                }
            }
            return data;
        }
    });

    const originalSubmit = liveForm.submit;

    // We expose a loading ref to match the v1 signature
    // We also map the backend result error format back to the form state
    const submit = async (): Promise<AlvaResult> => {
        loading.value = true;
        let rollbackFn: (() => void) | void = undefined;
        if (options.onOptimisticSubmit) {
            rollbackFn = options.onOptimisticSubmit(pseudoForm.values);
        }

        let result: any;
        try {
            result = await originalSubmit();
            loading.value = false;
        } catch (e: any) {
            loading.value = false;
            if (rollbackFn) rollbackFn();
            return { ok: false, error: { type: "unknown", message: e.message || String(e) } };
        }

        if (result && !result.ok && result.error && result.error.fields) {
            // Ash backend returned validation errors, sync them to our pseudoForm
            for (const key of Object.keys(pseudoForm.errors)) {
                delete (pseudoForm.errors as any)[key];
            }
            Object.assign(pseudoForm.errors, result.error.fields);
            if (rollbackFn) rollbackFn();
        } else if (result && result.ok) {
            // Success, clear errors
            for (const key of Object.keys(pseudoForm.errors)) {
                delete (pseudoForm.errors as any)[key];
            }
        } else if (rollbackFn) {
             rollbackFn();
        }

        return result;
    };

    // Since useLiveForm handles validation internally via changeEvent, we mock a manual validate
    const validate = async (): Promise<AlvaResult> => {
        // live_vue handles the validation transparently, but if the user calls validate() manually,
        // we just return a stub indicating ok (or we could wait for isValidating to become false).
        // For Alva V1 compatibility, returning a stub.
        return { ok: true, data: {} };
    };

    return {
        ...liveForm,
        submit,
        validate,
        loading,
        errors: ref(pseudoForm.errors), // Compatibility
        values: pseudoForm.values as FormValues, // Compatibility
    };
}
