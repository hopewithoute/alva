import { flushPromises, mount } from "@vue/test-utils";
import { beforeEach, describe, expect, it, vi } from "vitest";

import DemoNotificationsPage from "./DemoNotificationsPage.vue";

import { ref, type Ref } from "vue";

const { ashCallMock, sentState } = vi.hoisted(() => ({
  ashCallMock: vi.fn(),
  sentState: {} as { current: Ref<Array<Record<string, unknown>>> }
}));

vi.mock("@/js/alva", async () => {
  const { ref } = await import("vue");
  const noticesRef = ref<Array<Record<string, unknown>>>([]);
  sentState.current = noticesRef;
  return {
    useAlva: () => ({
      demo_notifications: {
        send: ashCallMock,
        use_sent_state: () => ({ data: noticesRef })
      }
    })
  };
});

describe("DemoNotificationsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    sentState.current.value = [];
    ashCallMock.mockResolvedValue({ ok: true, data: null });
  });

  it("publishes notifications and renders incoming signal payloads", async () => {
    const wrapper = mount(DemoNotificationsPage);

    await wrapper.get("#demo-notification-title").setValue("Inventory sync complete");
    await wrapper.findComponent({ name: "Select" }).vm.$emit("update:modelValue", "warning");
    await wrapper.get("form").trigger("submit.prevent");
    await flushPromises();

    expect(ashCallMock).toHaveBeenCalledWith({
      title: "Inventory sync complete",
      severity: "warning"
    });

    sentState.current.value = [
      {
        id: "notice-1",
        title: "Inventory sync complete",
        severity: "warning"
      }
    ];
    await flushPromises();

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
