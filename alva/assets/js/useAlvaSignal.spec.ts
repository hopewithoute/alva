import { beforeEach, describe, expect, it, vi } from "vitest";
import { useAlvaSignal } from "./useAlvaSignal";
import { useLiveEvent } from "live_vue";
import * as useAlvaSubscriptions from "./useAlvaSubscriptions";

vi.mock("vue", () => ({
    onUnmounted: vi.fn((fn) => {
        (globalThis as any)._unmountCallback = fn;
    }),
}));

vi.mock("live_vue", () => ({
    useLiveEvent: vi.fn(),
}));

vi.mock("./useAlvaSubscriptions", () => ({
    useAlvaSubscriptions: vi.fn(),
}));

describe("useAlvaSignal", () => {
    let mockActivate: any;
    let mockDeactivate: any;

    beforeEach(() => {
        vi.clearAllMocks();
        delete (globalThis as any)._unmountCallback;

        mockActivate = vi.fn().mockResolvedValue({ ok: true });
        mockDeactivate = vi.fn().mockResolvedValue({ ok: true });

        vi.mocked(useAlvaSubscriptions.useAlvaSubscriptions).mockReturnValue({
            activate: mockActivate,
            deactivate: mockDeactivate,
        } as any);
    });

    it("activates the typed signal and registers the LiveView event listener", () => {
        const callback = vi.fn();

        useAlvaSignal("demo_notifications_sent", {}, callback);

        expect(mockActivate).toHaveBeenCalledWith("demo_notifications_sent", {});
        expect(useLiveEvent).toHaveBeenCalledWith("demo_notifications_sent", callback);
    });

    it("deactivates the signal on unmount", () => {
        useAlvaSignal("demo_notifications_sent", {}, vi.fn());

        (globalThis as any)._unmountCallback();

        expect(mockDeactivate).toHaveBeenCalledWith("demo_notifications_sent", {});
    });
});
