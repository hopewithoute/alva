import { describe, it, expect, vi } from "vitest";
import { ashUpload } from "./ashUpload";
import { ref } from "vue";

// Mock useLiveUpload
vi.mock("live_vue", () => {
    return {
        useLiveUpload: vi.fn((name: string) => ({
            name,
            entries: ref([]),
            errors: ref([]),
            cancel: vi.fn(),
        })),
    };
});

import { useLiveUpload } from "live_vue";

describe("ashUpload", () => {
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
                { ref: "1", progress: 100, size: 1000, name: "", type: "" },
                { ref: "2", progress: 0, size: 99000, name: "", type: "" },
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
                { ref: "1", size: 10, name: "", type: "", progress: 0 },
                { ref: "2", size: 10, name: "", type: "", progress: 0 },
                { ref: "3", size: 10, name: "", type: "", progress: 0 },
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
                { ref: "1", size: 1000, name: "", type: "", progress: 0 },
                { ref: "2", size: 5000, name: "", type: "", progress: 0 },
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
                { ref: "ref-123", size: 10, name: "", type: "", progress: 0 },
                { ref: "ref-456", size: 10, name: "", type: "", progress: 0 },
            ]),
            errors: ref([]),
            cancel: vi.fn(),
        });

        const { getFileReferences } = ashUpload("avatar");
        expect(getFileReferences()).toEqual(["ref-123", "ref-456"]);
    });
});
