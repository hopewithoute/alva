import { beforeEach, describe, expect, it, vi } from "vitest";
import { ash } from "./ash";
import { useLiveEvent, useLiveVue } from "live_vue";

vi.mock("vue", () => ({
    onUnmounted: vi.fn((fn) => {
        (globalThis as any)._unmountCallback = fn;
    }),
}));

vi.mock("live_vue", () => ({
    useLiveEvent: vi.fn(),
    useLiveVue: vi.fn(),
}));

describe("ash.on", () => {
    let mockPushEvent: any;

    beforeEach(() => {
        vi.clearAllMocks();
        delete (globalThis as any)._unmountCallback;

        mockPushEvent = vi.fn();
        vi.mocked(useLiveVue).mockReturnValue({
            pushEvent: mockPushEvent
        } as any);
    });

    it("activates the typed signal and registers the LiveView event listener", () => {
        const callback = vi.fn();

        ash.on("demo_notifications_sent", {}, callback);

        expect(mockPushEvent).toHaveBeenCalledWith(
            "alva:subscribe_signal",
            { name: "demo_notifications_sent", input: {} },
            expect.any(Function)
        );
        expect(useLiveEvent).toHaveBeenCalledWith("demo_notifications_sent", callback);
    });

    it("deactivates the signal on unmount", () => {
        ash.on("demo_notifications_sent", {}, vi.fn());

        (globalThis as any)._unmountCallback();

        expect(mockPushEvent).toHaveBeenCalledWith(
            "alva:unsubscribe_signal",
            { name: "demo_notifications_sent", input: {} },
            expect.any(Function)
        );
    });
});
