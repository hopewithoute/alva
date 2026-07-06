import { computed, ref, watch } from "vue";
import { useLiveUpload, useLiveVue } from "live_vue";

export interface UploadEntry {
    ref: string;
    client_name?: string;
    client_size?: number;
    client_type?: string;
    name?: string;
    size?: number;
    type?: string;
    progress: number;
    error?: string;
}

export interface UseLiveUploadReturn {
    name: string;
    entries: { value: UploadEntry[] };
    errors: { value: any[] };
    cancel: (ref: string) => void;
    showFilePicker: () => void;
    clear: () => void;
}

export interface AshUploadOptions {
    maxFiles?: number;
    maxSize?: number; // in bytes
}

type UploadConfigShape = {
    ref: string;
    name: string;
    accept: string | false;
    max_entries: number;
    auto_upload: boolean;
    entries: UploadEntry[];
    errors: unknown[];
};

export function ashUpload(name: string, options?: AshUploadOptions) {
    const live = useLiveVue();

    const getUploadConfig = () => resolveUploadConfig(live.vue?.props, name);
    const initialConfig = getUploadConfig();

    if (!initialConfig) {
        return missingUpload(name);
    }

    // @ts-ignore
    const upload = useLiveUpload(getUploadConfig, {
        changeEvent: "validate_upload",
        submitEvent: "save_upload",
        ...(options || {})
    }) as unknown as UseLiveUploadReturn;

    const files = computed(() => upload.entries?.value || []);
    const errors = computed(() => upload.errors?.value || []);

    const progress = computed(() => {
        if (files.value.length === 0) return 0;
        let totalSize = 0;
        let totalUploaded = 0;
        for (const file of files.value) {
            const size = uploadEntrySize(file);
            totalSize += size;
            totalUploaded += size * ((file.progress || 0) / 100);
        }
        return totalSize === 0
            ? 0
            : Math.round((totalUploaded / totalSize) * 100);
    });

    // Actively enforce limits by cancelling offending uploads
    const enforceLimits = () => {
        if (!options || !upload.cancel) return;

        if (options.maxFiles && files.value.length > options.maxFiles) {
            const toRemove = files.value.slice(options.maxFiles);
            toRemove.forEach((file: UploadEntry) => upload.cancel(file.ref));
        }

        if (options.maxSize) {
            files.value.forEach((file: UploadEntry) => {
                if (uploadEntrySize(file) > options.maxSize!) {
                    upload.cancel(file.ref);
                }
            });
        }
    };

    // Watch for new files and enforce limits automatically
    watch(
        files,
        () => {
            enforceLimits();
        },
        { deep: true, immediate: true },
    );

    // Gets file references for ash_storage actions
    const getFileReferences = () => {
        return files.value.map((file: UploadEntry) => file.ref);
    };

    return {
        ...upload,
        files,
        errors,
        progress,
        getFileReferences,
    };
}

function uploadEntrySize(file: UploadEntry) {
    return file.client_size ?? file.size ?? 0;
}

function resolveUploadConfig(
    uploadProps: Record<string, unknown> | null | undefined,
    name: string,
): UploadConfigShape | null {
    const directConfig = uploadProps?.[name];

    if (isUploadConfig(directConfig)) {
        return directConfig;
    }

    const nestedUploads = uploadProps?.uploads;

    if (
        nestedUploads &&
        typeof nestedUploads === "object" &&
        !Array.isArray(nestedUploads)
    ) {
        const nestedConfig = (nestedUploads as Record<string, unknown>)[name];

        if (isUploadConfig(nestedConfig)) {
            return nestedConfig;
        }
    }

    return null;
}

function isUploadConfig(value: unknown): value is UploadConfigShape {
    return Boolean(
        value &&
            typeof value === "object" &&
            typeof (value as UploadConfigShape).ref === "string" &&
            typeof (value as UploadConfigShape).name === "string" &&
            Array.isArray((value as UploadConfigShape).entries) &&
            Array.isArray((value as UploadConfigShape).errors),
    );
}

function missingUpload(name: string) {
    const files = ref<UploadEntry[]>([]);
    const errors = computed(() => []);
    const progress = computed(() => 0);
    const inputEl = ref<HTMLInputElement | null>(null);
    const valid = computed(() => false);
    const warning =
        `[alva/ashUpload] Missing LiveView upload config for "${name}". ` +
        `Pass the matching upload prop to the LiveVue component, for example ` +
        `${name}={@uploads.${name}}.`;

    const warn = () => {
        console.warn(warning);
    };

    return {
        name,
        entries: files,
        files,
        errors,
        progress,
        inputEl,
        valid,
        showFilePicker: warn,
        addFiles: warn,
        submit: warn,
        cancel: () => {},
        clear: () => {},
        getFileReferences: () => [],
    };
}
