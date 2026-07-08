import { beforeEach, describe, expect, it, vi } from "vitest";

const { addEventListenerMock, removeEventListenerMock, onScopeDisposeMock, useLiveVueMock } =
  vi.hoisted(() => ({
    addEventListenerMock: vi.fn(),
    removeEventListenerMock: vi.fn(),
    onScopeDisposeMock: vi.fn(),
    useLiveVueMock: vi.fn()
  }));

vi.mock("vue", () => ({
  onScopeDispose: onScopeDisposeMock
}));

vi.mock("live_vue", () => ({
  useLiveVue: useLiveVueMock
}));

describe("useAlvaSubscriptions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.resetModules();

    const listeners = new Map<string, Set<EventListener>>();

    addEventListenerMock.mockImplementation((eventName: string, callback: EventListener) => {
      const existing = listeners.get(eventName) ?? new Set<EventListener>();
      existing.add(callback);
      listeners.set(eventName, existing);
    });

    removeEventListenerMock.mockImplementation((eventName: string, callback: EventListener) => {
      const existing = listeners.get(eventName);

      if (!existing) {
        return;
      }

      existing.delete(callback);

      if (existing.size === 0) {
        listeners.delete(eventName);
      }
    });

    onScopeDisposeMock.mockImplementation((callback: () => void) => {
      (globalThis as any)._disposeCallback = callback;
    });

    (globalThis as any)._listeners = listeners;
    (globalThis as any)._disposeCallback = undefined;
    (globalThis as any).window = {
      addEventListener: addEventListenerMock,
      removeEventListener: removeEventListenerMock
    };
  });

  it("does not replay subscriptions during the first initial load event", async () => {
    const liveA = {
      pushEvent: vi.fn((_name, _payload, callback) => callback?.({ ok: true }))
    };
    const liveB = {
      pushEvent: vi.fn((_name, _payload, callback) => callback?.({ ok: true }))
    };

    useLiveVueMock
      .mockReturnValueOnce(liveA)
      .mockReturnValueOnce(liveB);

    const { useAlvaSubscriptions } = await import("./useAlvaSubscriptions");

    const hookA = useAlvaSubscriptions();
    const hookB = useAlvaSubscriptions();

    await hookA.activate("sales_orders", { sort: "-created_at" });
    await hookB.activate("support_messages", { conversation_id: "conv-1" });

    const reconnectHandlers = Array.from(
      (globalThis as any)._listeners.get("phx:page-loading-stop") ?? []
    ) as EventListener[];
    reconnectHandlers.forEach((handler) => handler({ detail: { kind: "initial" } } as Event));

    expect(liveA.pushEvent).toHaveBeenCalledTimes(1);
    expect(liveB.pushEvent).toHaveBeenCalledTimes(1);
  });

  it("replays each hook's active subscriptions through its own LiveVue handle on reconnect", async () => {
    const liveA = {
      pushEvent: vi.fn((_name, _payload, callback) => callback?.({ ok: true }))
    };
    const liveB = {
      pushEvent: vi.fn((_name, _payload, callback) => callback?.({ ok: true }))
    };

    useLiveVueMock
      .mockReturnValueOnce(liveA)
      .mockReturnValueOnce(liveB);

    const { useAlvaSubscriptions } = await import("./useAlvaSubscriptions");

    const hookA = useAlvaSubscriptions();
    const hookB = useAlvaSubscriptions();

    await hookA.activate("sales_orders", { customer_query: "Alice" });
    await hookB.activate("support_messages", { conversation_id: "conv-2" });

    const reconnectHandlers = Array.from(
      (globalThis as any)._listeners.get("phx:page-loading-stop") ?? []
    ) as EventListener[];
    reconnectHandlers.forEach((handler) => handler({ detail: { kind: "initial" } } as Event));
    reconnectHandlers.forEach((handler) => handler({ detail: { kind: "initial" } } as Event));

    expect(liveA.pushEvent).toHaveBeenNthCalledWith(
      2,
      "alva:activate_subscription",
      { name: "sales_orders", input: { customer_query: "Alice" } },
      expect.any(Function)
    );
    expect(liveB.pushEvent).toHaveBeenNthCalledWith(
      2,
      "alva:activate_subscription",
      { name: "support_messages", input: { conversation_id: "conv-2" } },
      expect.any(Function)
    );
  });

  it("removes the reconnect listener when the composable scope is disposed", async () => {
    const live = {
      pushEvent: vi.fn((_name, _payload, callback) => callback?.({ ok: true }))
    };

    useLiveVueMock.mockReturnValue(live);

    const { useAlvaSubscriptions } = await import("./useAlvaSubscriptions");

    const hook = useAlvaSubscriptions();
    await hook.activate("demo_notifications_sent", {});

    const disposeCallback = (globalThis as any)._disposeCallback as (() => void) | undefined;
    disposeCallback?.();

    expect(removeEventListenerMock).toHaveBeenCalledWith(
      "phx:page-loading-stop",
      expect.any(Function)
    );

    const reconnectHandlers = Array.from(
      (globalThis as any)._listeners.get("phx:page-loading-stop") ?? []
    ) as EventListener[];
    reconnectHandlers.forEach((handler) => handler({ detail: { kind: "initial" } } as Event));

    expect(live.pushEvent).toHaveBeenCalledTimes(1);
  });
});
