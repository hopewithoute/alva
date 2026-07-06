import { computed, watch } from "vue";
import { useLiveUpload, useLiveVue } from "live_vue";

export interface UploadEntry {
    ref: string;
    name: string;
    size: number;
    type: string;
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

export function ashUpload(name: string, options?: AshUploadOptions) {
    const live = useLiveVue();

    // Provide a dummy config if the upload prop is not passed from LiveView
    // This prevents crashes in live_vue's useLiveUpload which expects a valid config.
    const getUploadConfig = () => {
        const uploadProps = live.vue?.props;

        return uploadProps?.[name] || {
            ref: "dummy-ref",
            name: name,
            accept: false,
            max_entries: options?.maxFiles || 1,
            auto_upload: false,
            entries: [],
            errors: []
        };
    };

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
            totalSize += file.size || 0;
            totalUploaded += (file.size || 0) * ((file.progress || 0) / 100);
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
                if (file.size > options.maxSize!) {
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
