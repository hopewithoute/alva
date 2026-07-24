import { flushPromises, mount } from "@vue/test-utils";
import { beforeEach, describe, expect, it, vi } from "vitest";

import StorefrontHeader from "./StorefrontHeader.vue";

const { apiCall, patchQueryMock } = vi.hoisted(() => ({
  apiCall: vi.fn(),
  patchQueryMock: vi.fn()
}));

vi.mock("@/js/alva", () => ({
  useAlva: () => ({
    support: {
      get_conversation: apiCall
    }
  })
}));

vi.mock("@/vue/shared/useRouteQueryPatch", () => ({
  useRouteQueryPatch: () => ({
    patchQuery: patchQueryMock
  })
}));

const mountHeader = (connectedCustomerName: string | null = null) =>
  mount(StorefrontHeader, {
    props: {
      recentOrderCount: 2,
      recentOrderItems: 3,
      connectedCustomerName
    }
  });

describe("StorefrontHeader", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
  });

  it("looks up the current shopper conversation before patching storefront identity", async () => {
    apiCall.mockResolvedValue({
      ok: true,
      data: { id: "conv-123" }
    });

    const wrapper = mountHeader();

    await wrapper.get("#customerName").setValue("Alice");
    await vi.advanceTimersByTimeAsync(500);
    await flushPromises();

    expect(apiCall).toHaveBeenCalledWith({
      customer_name: "Alice"
    });
    expect(patchQueryMock).toHaveBeenCalledWith({
      customer_name: "Alice",
      conversation_id: "conv-123"
    });
  });

  it("clears the route identity when the shopper name is emptied", async () => {
    const wrapper = mountHeader("Alice");

    await wrapper.get("#customerName").setValue("");
    await vi.advanceTimersByTimeAsync(500);
    await flushPromises();

    expect(apiCall).not.toHaveBeenCalled();
    expect(patchQueryMock).toHaveBeenCalledWith({
      customer_name: null,
      conversation_id: null
    });
  });
});
