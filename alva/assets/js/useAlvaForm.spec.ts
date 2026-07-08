import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { useAlvaForm } from "./useAlvaForm";
import { effectScope, nextTick, ref } from "vue";
import * as live_vue from "live_vue";

vi.mock("live_vue", () => {
    return {
        useLiveForm: vi.fn((form, opts) => ({
            submit: vi.fn(),
            isValid: ref(true),
            isValidating: ref(false),
            values: form.values,
            reset: vi.fn(),
        }))
    };
});

describe("useAlvaForm", () => {
    const mockApi = () => {
        return {
            call: vi.fn(),
        };
    };

    beforeEach(() => {
        vi.clearAllMocks();
    });

    it("should initialize and wrap live_vue.useLiveForm", () => {
        const { values } = useAlvaForm("students.create", {
            initialValues: { name: "A" }
        });

        expect(values).toEqual({ name: "A" });
        expect(live_vue.useLiveForm).toHaveBeenCalled();
    });

    it("should handle optimistic UI rollback on submit", async () => {
        const api = mockApi();
        const rollbackFn = vi.fn();
        const onOptimisticSubmit = vi.fn(() => rollbackFn);

        // Mock submit failure
        const mockSubmit = vi.fn().mockRejectedValue(new Error("network down"));
        vi.mocked(live_vue.useLiveForm).mockReturnValue({
            submit: mockSubmit,
            isValid: ref(true),
            isValidating: ref(false),
            values: { name: "A" },
            reset: vi.fn(),
        } as any);

        const form = useAlvaForm("students.create", {
            initialValues: { name: "A" },
            onOptimisticSubmit
        });

        const result = await form.submit();

        expect(result.ok).toBe(false);
        expect(onOptimisticSubmit).toHaveBeenCalledWith({ name: "A" });
        expect(rollbackFn).toHaveBeenCalledTimes(1);
    });

    it("should handle validation errors on submit without throwing", async () => {
        const api = mockApi();
        const mockSubmit = vi.fn().mockResolvedValue({
            ok: false,
            error: { type: "validation", fields: { name: ["can't be blank"] } }
        });

        vi.mocked(live_vue.useLiveForm).mockReturnValue({
            submit: mockSubmit,
            isValid: ref(true),
            isValidating: ref(false),
            values: { name: "A" },
            reset: vi.fn(),
        } as any);

        const form = useAlvaForm("students.create", {
            initialValues: { name: "A" }
        });

        const result = await form.submit();

        expect(result.ok).toBe(false);
    });

    it("should map uploads via prepareData", () => {
        const api = mockApi();
        const getFileReferences = vi.fn(() => ["ref-1"]);
        
        useAlvaForm("students.create", {
            initialValues: { name: "A" },
            uploads: { avatar: { getFileReferences } as any }
        });

        const prepareData = vi.mocked(live_vue.useLiveForm).mock.calls[0][1]!.prepareData!;
        const data = prepareData({ name: "A" });

        expect(data).toEqual({ name: "A", avatar: ["ref-1"] });
    });
});
