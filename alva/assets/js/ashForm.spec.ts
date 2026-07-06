import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { ashForm } from "./ashForm";
import { effectScope, nextTick } from "vue";

describe("ashForm", () => {
    const mockApi = () => {
        return {
            call: vi.fn(),
        };
    };

    beforeEach(() => {
        vi.useFakeTimers();
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it("should initialize with provided values", () => {
        const api = mockApi();
        const { values, errors, loading } = ashForm(
            api as any,
            "students.create",
            {
                initialValues: { name: "Test" },
            },
        );

        expect(values.name).toBe("Test");
        expect(errors.value).toEqual({});
        expect(loading.value).toBe(false);
    });

    it("should handle successful submission", async () => {
        const api = mockApi();
        api.call.mockResolvedValue({ ok: true, data: { id: 1 } });

        const { values, submit, loading } = ashForm(
            api as any,
            "students.create",
            {
                initialValues: { name: "Test" },
            },
        );

        const promise = submit();
        expect(loading.value).toBe(true);

        const result = await promise;
        expect(loading.value).toBe(false);
        expect(result).toEqual({ ok: true, data: { id: 1 } });
        expect(api.call).toHaveBeenCalledWith("students.create", {
            name: "Test",
        });
    });

    it("should handle validation errors on submit", async () => {
        const api = mockApi();
        api.call.mockResolvedValue({
            ok: false,
            error: { type: "validation", fields: { name: ["can't be blank"] } },
        });

        const { submit, errors } = ashForm(api as any, "students.create", {
            initialValues: { name: "" },
        });

        await submit();
        expect(errors.value).toEqual({ name: ["can't be blank"] });
    });

    it("should not map errors if type is not validation", async () => {
        const api = mockApi();
        api.call.mockResolvedValue({
            ok: false,
            error: { type: "forbidden", message: "Not allowed" },
        });

        const { submit, errors } = ashForm(api as any, "students.create", {
            initialValues: { name: "Test" },
        });

        await submit();
        expect(errors.value).toEqual({});
    });

    it("should debounce validation on field change", async () => {
        const api = mockApi();
        api.call.mockResolvedValue({ ok: true });

        const { values, isValidating } = ashForm(
            api as any,
            "students.create",
            {
                initialValues: { name: "A" },
                validateEvent: "students.validate",
            },
        );

        // Change value
        values.name = "B";
        await nextTick(); // Let watcher trigger

        expect(isValidating.value).toBe(true);
        expect(api.call).not.toHaveBeenCalled();

        // Fast forward timer
        vi.advanceTimersByTime(300);

        // Wait for promise resolution using real timers
        vi.useRealTimers();
        await new Promise((resolve) => setTimeout(resolve, 0));

        expect(api.call).toHaveBeenCalledWith("students.validate", {
            name: "B",
        });
        expect(isValidating.value).toBe(false);
    });

    it("should resolve hanging validation promises with cancelled status", async () => {
        const api = mockApi();
        api.call.mockResolvedValue({ ok: true });

        const { validate } = ashForm(api as any, "students.create", {
            initialValues: { name: "A" },
            validateEvent: "students.validate",
        });

        const promise1 = validate();
        const promise2 = validate();

        vi.advanceTimersByTime(300);
        vi.useRealTimers();

        const [res1, res2] = await Promise.all([promise1, promise2]);

        expect(res1).toEqual({
            ok: false,
            error: { type: "cancelled", message: "Superseded" },
        });
        expect(res2).toEqual({ ok: true }); // The second one actually runs
        expect(api.call).toHaveBeenCalledTimes(1); // Only one call made it through the debounce
    });

    it("should cancel pending validation when submit is called to prevent race conditions", async () => {
        const api = mockApi();
        api.call.mockResolvedValue({ ok: true });

        const { values, submit, errors } = ashForm(
            api as any,
            "students.create",
            {
                initialValues: { name: "A" },
                validateEvent: "students.validate",
            },
        );

        // Trigger validation
        values.name = "B";
        await nextTick();

        // Call submit immediately
        const submitPromise = submit();

        vi.advanceTimersByTime(300);
        vi.useRealTimers();

        await submitPromise;

        // Validate shouldn't have been called because submit cancelled it
        expect(api.call).toHaveBeenCalledTimes(1);
        expect(api.call).toHaveBeenCalledWith("students.create", { name: "B" });
    });

    it("should reset form", () => {
        const api = mockApi();
        const { values, errors, reset } = ashForm(
            api as any,
            "students.create",
            {
                initialValues: { name: "A" },
            },
        );

        values.name = "B";
        errors.value = { name: ["bad"] };

        reset();

        expect(values.name).toBe("A");
        expect(errors.value).toEqual({});
    });

    it("should attach uploads to submit payload", async () => {
        const api = mockApi();
        api.call.mockResolvedValue({ ok: true });

        const mockUpload = {
            getFileReferences: () => ["ref-1", "ref-2"],
        };

        const { submit } = ashForm(api as any, "students.create", {
            initialValues: { name: "Test" },
            uploads: {
                avatar: mockUpload,
            },
        });

        await submit();

        expect(api.call).toHaveBeenCalledWith("students.create", {
            name: "Test",
            avatar: ["ref-1", "ref-2"],
        });
    });

    it("should not overwrite submit errors with stale validate responses (race condition)", async () => {
        type Resolver = (value: any) => void;
        let resolve_validate: Resolver | undefined;
        let resolve_submit: Resolver | undefined;

        const api_routes = {
            "students.validate": () =>
                new Promise((r) => (resolve_validate = r)),
            "students.create": () => new Promise((r) => (resolve_submit = r)),
        };

        const api_mock = {
            call: vi
                .fn()
                .mockImplementation((event: keyof typeof api_routes) => {
                    return api_routes[event]();
                }),
        };

        const flush_microtasks = async () => {
            await Promise.resolve();
            await Promise.resolve();
            await nextTick();
        };

        const { values, submit, validate, errors, loading, isValidating } =
            ashForm(api_mock as any, "students.create", {
                initialValues: { name: "" },
                validateEvent: "students.validate",
                debounceMs: 300,
            });

        // 1. Trigger validation
        validate();

        // 2. Wait for debounce to finish so the API call starts
        vi.advanceTimersByTime(300);
        await nextTick();

        // Now validate API call is in-flight (waiting on resolve_validate)

        // 3. Trigger submit
        const submit_promise = submit();

        // Now submit API call is in-flight (waiting on resolve_submit)

        // 4. Submit API call finishes with errors
        resolve_submit?.({
            ok: false,
            error: { type: "validation", fields: { name: ["Submit error"] } },
        });
        await submit_promise;
        await nextTick();

        expect(errors.value.name).toEqual(["Submit error"]);
        expect(loading.value).toBe(false);
        expect(isValidating.value).toBe(false); // Validation state should be reset by submit

        // 5. Stale validate API call finishes later
        resolve_validate?.({
            ok: false,
            error: { type: "validation", fields: { name: ["Validate error"] } },
        });

        // Await pending microtasks
        await flush_microtasks();

        // The stale validate response should NOT overwrite the submit errors
        expect(errors.value.name).toEqual(["Submit error"]);
    });

    it("should invoke onOptimisticSubmit and rollback if submit fails", async () => {
        const api = mockApi();
        api.call.mockResolvedValue({
            ok: false,
            error: { type: "validation", fields: { name: ["bad"] } },
        });

        const rollbackFn = vi.fn();
        const onOptimisticSubmit = vi.fn().mockReturnValue(rollbackFn);

        const { values, submit } = ashForm(api as any, "students.create", {
            initialValues: { name: "A" },
            onOptimisticSubmit,
        });

        values.name = "B";
        await submit();

        expect(onOptimisticSubmit).toHaveBeenCalledWith({ name: "B" });
        expect(rollbackFn).toHaveBeenCalled();
    });

    it("should invoke rollback if submit throws after optimistic submit", async () => {
        const api = mockApi();
        api.call.mockRejectedValue(new Error("network down"));

        const rollbackFn = vi.fn();
        const onOptimisticSubmit = vi.fn().mockReturnValue(rollbackFn);

        const { values, submit } = ashForm(api as any, "students.create", {
            initialValues: { name: "A" },
            onOptimisticSubmit,
        });

        values.name = "B";

        await expect(submit()).rejects.toThrow("network down");
        expect(onOptimisticSubmit).toHaveBeenCalledWith({ name: "B" });
        expect(rollbackFn).toHaveBeenCalledTimes(1);
    });

    it("should cache validation responses and skip api calls for identical payloads", async () => {
        const api = mockApi();
        api.call.mockResolvedValue({ ok: true });

        const { validate } = ashForm(api as any, "students.create", {
            initialValues: { name: "A" },
            validateEvent: "students.validate",
        });

        // First validation
        const p1 = validate();
        vi.advanceTimersByTime(300);
        await p1;
        expect(api.call).toHaveBeenCalledTimes(1);

        // Second validation with identical payload
        const p2 = validate();
        vi.advanceTimersByTime(300);
        await p2;

        // Should hit cache
        expect(api.call).toHaveBeenCalledTimes(1);
    });

    it("should clear the validation cache when the form scope is disposed", async () => {
        const api = mockApi();
        api.call.mockResolvedValue({ ok: true });

        const scope = effectScope();

        const { validate } = scope.run(() =>
            ashForm(api as any, "students.create", {
                initialValues: { name: "A" },
                validateEvent: "students.validate",
            }),
        )!;

        const first = validate();
        vi.advanceTimersByTime(300);
        await first;
        expect(api.call).toHaveBeenCalledTimes(1);

        scope.stop();

        const second = validate();
        vi.advanceTimersByTime(300);
        await second;

        expect(api.call).toHaveBeenCalledTimes(2);
    });
});
