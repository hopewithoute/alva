import { beforeEach, describe, expect, it, vi } from "vitest";
import { ashUpload } from "./ashUpload";
import { ref } from "vue";

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

describe("ashUpload", () => {
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
        const { files, errors, progress, name } = ashUpload("avatar");

        expect(name).toBe("avatar");
        expect(files.value).toEqual([]);
        expect(errors.value).toEqual([]);
        expect(progress.value).toBe(0);
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

        const { progress, files } = ashUpload("avatar");

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

        ashUpload("avatar", { maxFiles: 2 });
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

        ashUpload("avatar", { maxSize: 4000 });
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

        const { getFileReferences } = ashUpload("avatar");
        expect(getFileReferences()).toEqual(["ref-123", "ref-456"]);
    });

    it("fails loud without sending a dummy upload ref when config is missing", () => {
        const warning = vi.spyOn(console, "warn").mockImplementation(() => {});

        vi.mocked(useLiveVue).mockReturnValueOnce({
            vue: {
                props: {},
            },
        } as any);

        const upload = ashUpload("avatar");
        upload.showFilePicker();

        expect(vi.mocked(useLiveUpload)).not.toHaveBeenCalled();
        expect(upload.getFileReferences()).toEqual([]);
        expect(warning).toHaveBeenCalledWith(
            expect.stringContaining('Missing LiveView upload config for "avatar"'),
        );

        warning.mockRestore();
    });
});
