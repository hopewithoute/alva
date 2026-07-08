import { describe, it, expect, vi, beforeEach } from "vitest";
import { usePageEvent } from "./usePageEvent";
import { useLiveVue } from "live_vue";

vi.mock("live_vue", () => {
    return {
        useLiveVue: vi.fn(),
    };
});

type TestEvents = {
    "support.join_chat": {
        input: { customer_name?: string };
        output:
            | { ok: true; data: void }
            | { ok: false; error: { type: string; message: string } };
    };
};

describe("usePageEvent", () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it("returns successful replies and clears loading", async () => {
        const pushEventMock = vi.fn().mockResolvedValue({
            ok: true,
            data: undefined,
        });

        vi.mocked(useLiveVue).mockReturnValue({
            pushEvent: pushEventMock,
        } as any);

        const pageEvent = usePageEvent<TestEvents, "support.join_chat">("support.join_chat");
        const result = await pageEvent.call({ customer_name: "Alice" });

        expect(pushEventMock).toHaveBeenCalledWith("support.join_chat", {
            customer_name: "Alice",
        });
        expect(result).toEqual({ ok: true, data: undefined });
        expect(pageEvent.error.value).toBeNull();
        expect(pageEvent.isLoading.value).toBe(false);
    });

    it("stores reply-level failures on the error ref", async () => {
        const pushEventMock = vi.fn().mockResolvedValue({
            ok: false,
            error: {
                type: "validation",
                message: "Customer name is required.",
            },
        });

        vi.mocked(useLiveVue).mockReturnValue({
            pushEvent: pushEventMock,
        } as any);

        const pageEvent = usePageEvent<TestEvents, "support.join_chat">("support.join_chat");
        const result = await pageEvent.call({});

        expect(result).toEqual({
            ok: false,
            error: {
                type: "validation",
                message: "Customer name is required.",
            },
        });
        expect(pageEvent.error.value).toEqual({
            type: "validation",
            message: "Customer name is required.",
        });
        expect(pageEvent.isLoading.value).toBe(false);
    });

    it("converts thrown transport errors into structured failures", async () => {
        const pushEventMock = vi.fn().mockRejectedValue(new Error("Socket disconnected"));

        vi.mocked(useLiveVue).mockReturnValue({
            pushEvent: pushEventMock,
        } as any);

        const pageEvent = usePageEvent<TestEvents, "support.join_chat">("support.join_chat");
        const result = await pageEvent.call({ customer_name: "Alice" });

        expect(result).toEqual({
            ok: false,
            error: {
                type: "unknown",
                message: "Socket disconnected",
            },
        });
        expect(pageEvent.error.value).toEqual({
            type: "unknown",
            message: "Socket disconnected",
        });
        expect(pageEvent.isLoading.value).toBe(false);
    });

    it("returns a structured error when no usable reply is received", async () => {
        const pushEventMock = vi.fn().mockResolvedValue(undefined);

        vi.mocked(useLiveVue).mockReturnValue({
            pushEvent: pushEventMock,
        } as any);

        const pageEvent = usePageEvent<TestEvents, "support.join_chat">("support.join_chat");
        const result = await pageEvent.call({ customer_name: "Alice" });

        expect(result).toEqual({
            ok: false,
            error: {
                type: "unknown",
                message: 'Page event "support.join_chat" failed before a reply was received.',
            },
        });
        expect(pageEvent.error.value).toEqual({
            type: "unknown",
            message: 'Page event "support.join_chat" failed before a reply was received.',
        });
        expect(pageEvent.isLoading.value).toBe(false);
    });
});
