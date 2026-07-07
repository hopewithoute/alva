import { nextTick, ref } from "vue";
import { beforeEach, describe, expect, it, vi } from "vitest";
import {
    ALVA_UPLOAD_CHANGE_EVENT,
    ALVA_UPLOAD_SUBMIT_EVENT,
    useAlvaUpload,
} from "./useAlvaUpload";

// Mock useLiveUpload
vi.mock("live_vue", () => {
    const buildUpload = (configOrFactory: any) => {
        const config =
            typeof configOrFactory === "function"
                ? configOrFactory()
                : configOrFactory;

        return {
            name: config?.name || "avatar",
            entries: ref([]),
            errors: ref([]),
            cancel: vi.fn(),
            showFilePicker: vi.fn(),
            clear: vi.fn(),
        };
    };

    return {
        useLiveVue: vi.fn(() => ({
            vue: {
                props: {},
            },
        })),
        useLiveUpload: vi.fn((configOrFactory: any) =>
            buildUpload(configOrFactory),
        ),
    };
});

import { useLiveUpload, useLiveVue } from "live_vue";

const uploadConfig = (name: string) => ({
    ref: `phx-${name}-ref`,
    name,
    accept: "image/*",
    max_entries: 2,
    auto_upload: true,
    entries: [],
    errors: [],
});

describe("useAlvaUpload", () => {
    beforeEach(() => {
        vi.clearAllMocks();
        vi.mocked(useLiveVue).mockReturnValue({
            vue: {
                props: {
                    avatar: uploadConfig("avatar"),
                },
            },
        } as any);
    });

    it("should initialize and map refs correctly", () => {
        const { files, errors, progress, name } = useAlvaUpload("avatar");

        expect(name).toBe("avatar");
        expect(files.value).toEqual([]);
        expect(errors.value).toEqual([]);
        expect(progress.value).toBe(0);
        expect(vi.mocked(useLiveUpload)).toHaveBeenCalledWith(
            expect.any(Function),
            expect.objectContaining({
                changeEvent: ALVA_UPLOAD_CHANGE_EVENT,
                submitEvent: ALVA_UPLOAD_SUBMIT_EVENT,
            }),
        );
    });

    it("should calculate aggregate progress by bytes", () => {
        vi.mocked(useLiveUpload).mockReturnValueOnce({
            name: "avatar",
            entries: ref([
                {
                    ref: "1",
                    progress: 100,
                    client_size: 1000,
                    client_name: "one.png",
                    client_type: "image/png",
                },
                {
                    ref: "2",
                    progress: 0,
                    client_size: 99000,
                    client_name: "two.png",
                    client_type: "image/png",
                },
            ]),
            errors: ref([]),
            cancel: vi.fn(),
        });

        const { progress, files } = useAlvaUpload("avatar");

        expect(files.value.length).toBe(2);
        // 1000 bytes uploaded out of 100000 total = 1%
        expect(progress.value).toBe(1);
    });

    it("should actively enforce maxFiles limit by cancelling", () => {
        const mockCancel = vi.fn();
        vi.mocked(useLiveUpload).mockReturnValueOnce({
            name: "avatar",
            entries: ref([
                { ref: "1", client_size: 10, progress: 0 },
                { ref: "2", client_size: 10, progress: 0 },
                { ref: "3", client_size: 10, progress: 0 },
            ]),
            errors: ref([]),
            cancel: mockCancel,
        });

        useAlvaUpload("avatar", { maxFiles: 2 });
        expect(mockCancel).toHaveBeenCalledWith("3");
    });

    it("should actively enforce maxSize limit by cancelling", () => {
        const mockCancel = vi.fn();
        vi.mocked(useLiveUpload).mockReturnValueOnce({
            name: "avatar",
            entries: ref([
                { ref: "1", client_size: 1000, progress: 0 },
                { ref: "2", client_size: 5000, progress: 0 },
            ]),
            errors: ref([]),
            cancel: mockCancel,
        });

        useAlvaUpload("avatar", { maxSize: 4000 });
        expect(mockCancel).toHaveBeenCalledWith("2");
    });

    it("should extract file references for form submission", () => {
        vi.mocked(useLiveUpload).mockReturnValueOnce({
            name: "avatar",
            entries: ref([
                { ref: "ref-123", client_size: 10, progress: 0 },
                { ref: "ref-456", client_size: 10, progress: 0 },
            ]),
            errors: ref([]),
            cancel: vi.fn(),
        });

        const { getFileReferences } = useAlvaUpload("avatar");
        expect(getFileReferences()).toEqual(["ref-123", "ref-456"]);
    });

    it("dispatches once the upload reference is ready and clears afterwards", async () => {
        const clear = vi.fn();
        const entries = ref([{ ref: "ref-123", client_size: 10, progress: 0 }]);
        vi.mocked(useLiveUpload).mockReturnValueOnce({
            name: "avatar",
            entries,
            errors: ref([]),
            cancel: vi.fn(),
            clear,
        });

        const upload = useAlvaUpload("avatar");
        const submit = vi.fn(async ({ primaryReference }) => ({
            ok: true,
            primaryReference,
        }));

        const resultPromise = upload.dispatch(submit);

        entries.value = [{ ref: "ref-123", client_size: 10, progress: 100 }];
        await nextTick();

        await expect(resultPromise).resolves.toEqual({
            ok: true,
            primaryReference: "ref-123",
        });
        expect(submit).toHaveBeenCalledWith(
            expect.objectContaining({
                primaryReference: "ref-123",
                references: ["ref-123"],
            }),
        );
        expect(clear).toHaveBeenCalledTimes(1);
    });

    it("clears the upload even when dispatch fails", async () => {
        const clear = vi.fn();
        const entries = ref([{ ref: "ref-123", client_size: 10, progress: 100 }]);
        vi.mocked(useLiveUpload).mockReturnValueOnce({
            name: "avatar",
            entries,
            errors: ref([]),
            cancel: vi.fn(),
            clear,
        });

        const upload = useAlvaUpload("avatar");

        await expect(
            upload.dispatch(async () => {
                throw new Error("Upload pipeline unavailable");
            }),
        ).rejects.toThrow("Upload pipeline unavailable");

        expect(clear).toHaveBeenCalledTimes(1);
    });

    it("fails loud without sending a dummy upload ref when config is missing", () => {
        const warning = vi.spyOn(console, "warn").mockImplementation(() => {});

        vi.mocked(useLiveVue).mockReturnValueOnce({
            vue: {
                props: {},
            },
        } as any);

        const upload = useAlvaUpload("avatar");
        upload.showFilePicker();

        expect(vi.mocked(useLiveUpload)).not.toHaveBeenCalled();
        expect(upload.getFileReferences()).toEqual([]);
        expect(warning).toHaveBeenCalledWith(
            expect.stringContaining('Missing LiveView upload config for "avatar"'),
        );

        warning.mockRestore();
    });

    it("fails loud when dispatch is attempted without upload config", async () => {
        const warning = vi.spyOn(console, "warn").mockImplementation(() => {});

        vi.mocked(useLiveVue).mockReturnValueOnce({
            vue: {
                props: {},
            },
        } as any);

        const upload = useAlvaUpload("avatar");

        await expect(upload.dispatch(async () => ({ ok: true }))).rejects.toThrow(
            'Missing LiveView upload config for "avatar"',
        );
        expect(warning).toHaveBeenCalledWith(
            expect.stringContaining('Missing LiveView upload config for "avatar"'),
        );

        warning.mockRestore();
    });
});
