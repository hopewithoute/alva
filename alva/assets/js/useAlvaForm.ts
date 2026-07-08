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
    submitEvent: SubmitEventKey,
    options: AlvaFormOptions<FormValues, keyof Events>,
): UseLiveFormReturn<FormValues> & { 
    submit: () => Promise<AlvaResult>; 
} {
    const pseudoForm = reactive({
        name: submitEvent as string,
        values: JSON.parse(JSON.stringify(options.initialValues)),
        errors: {},
        valid: true,
    }) as Form<FormValues>;

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

    // We map the backend result error format back to the form state
    const submit = async (): Promise<AlvaResult> => {
        let rollbackFn: (() => void) | void = undefined;
        if (options.onOptimisticSubmit) {
            rollbackFn = options.onOptimisticSubmit(pseudoForm.values);
        }

        let result: any;
        try {
            result = await originalSubmit();
        } catch (e: any) {
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

    return {
        ...liveForm,
        submit,
    } as any;
}
