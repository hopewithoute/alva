import { flushPromises, mount } from "@vue/test-utils";
import { beforeEach, describe, expect, it, vi } from "vitest";

import DemoNotificationsPage from "./DemoNotificationsPage.vue";

const { ashCallMock, signalRegistrations } = vi.hoisted(() => ({
  ashCallMock: vi.fn(),
  signalRegistrations: [] as Array<{
    name: string;
    input: Record<string, never>;
    callback: (payload: { id: string; title: string; severity: "info" | "success" | "warning" }) => void;
  }>
}));

vi.mock("alva", () => ({
  useAlvaSignal: (
    name: string,
    input: Record<string, never>,
    callback: (payload: { id: string; title: string; severity: "info" | "success" | "warning" }) => void
  ) => {
    signalRegistrations.push({ name, input, callback });
  }
}));

vi.mock("../../../js/alva/client", () => ({
  ashCall: ashCallMock
}));

describe("DemoNotificationsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    signalRegistrations.length = 0;
    ashCallMock.mockResolvedValue({ ok: true, data: null });
  });

  it("publishes notifications and renders incoming signal payloads", async () => {
    const wrapper = mount(DemoNotificationsPage);

    expect(signalRegistrations).toHaveLength(1);
    expect(signalRegistrations[0]?.name).toBe("demo_notifications_sent");
    expect(signalRegistrations[0]?.input).toEqual({});

    await wrapper.get("#demo-notification-title").setValue("Inventory sync complete");
    await wrapper.get("#demo-notification-severity").setValue("warning");
    await wrapper.get("form").trigger("submit.prevent");
    await flushPromises();

    expect(ashCallMock).toHaveBeenCalledWith("demo_notifications.send", {
      title: "Inventory sync complete",
      severity: "warning"
    });

    signalRegistrations[0]?.callback({
      id: "notice-1",
      title: "Inventory sync complete",
      severity: "warning"
    });
    await flushPromises();

    expect(wrapper.text()).toContain("1 received");
    expect(wrapper.text()).toContain("Inventory sync complete");
    expect(wrapper.text()).toContain("warning");
  });

  it("surfaces publish failures from the command path", async () => {
    ashCallMock.mockResolvedValue({
      ok: false,
      error: { message: "Notification publisher unavailable" }
    });

    const wrapper = mount(DemoNotificationsPage);

    await wrapper.get("#demo-notification-title").setValue("Outage");
    await wrapper.get("form").trigger("submit.prevent");
    await flushPromises();

    expect(wrapper.text()).toContain("Notification publisher unavailable");
  });
});
