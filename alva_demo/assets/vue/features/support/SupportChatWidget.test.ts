import { flushPromises, mount } from "@vue/test-utils";
import { beforeEach, describe, expect, it, vi } from "vitest";

import SupportChatWidget from "./SupportChatWidget.vue";

const { apiCall, patchQueryMock } = vi.hoisted(() => ({
  apiCall: vi.fn(),
  patchQueryMock: vi.fn()
}));

vi.mock("../../../js/alva/client", () => ({
  ashCall: apiCall
}));

vi.mock("../../shared/useRouteQueryPatch", () => ({
  useRouteQueryPatch: () => ({
    patchQuery: patchQueryMock
  })
}));

const mountWidget = () =>
  mount(SupportChatWidget, {
    props: {
      connectedCustomerName: "Alice",
      activeConversationId: null,
      supportMessages: []
    } as never,
    global: {
      stubs: {
        Button: {
          props: ["disabled"],
          emits: ["click"],
          template:
            '<button :disabled="disabled" @click="$emit(\'click\', $event)"><slot /></button>'
        }
      }
    }
  });

describe("SupportChatWidget", () => {
  beforeEach(() => {
    vi.clearAllMocks();

    apiCall.mockImplementation(async (event: string, payload?: Record<string, unknown>) => {
      if (event === "support.create") {
        return {
          ok: true,
          data: { id: "conv-123", customer_name: payload?.customer_name }
        };
      }

      if (event === "support.send_message") {
        return {
          ok: true,
          data: {
            id: "msg-1",
            conversation_id: payload?.conversation_id,
            sender: "shopper",
            text: payload?.text
          }
        };
      }

      return { ok: true, data: null };
    });
  });

  it("creates a conversation, patches the route, and sends the first message in one flow", async () => {
    const wrapper = mountWidget();
    const buttons = wrapper.findAll("button");

    await wrapper.get('input[type="text"]').setValue("Hello from storefront");
    await buttons[buttons.length - 1].trigger("click");
    await flushPromises();

    expect(apiCall).toHaveBeenNthCalledWith(1, "support.create", {
      customer_name: "Alice"
    });
    expect(patchQueryMock).toHaveBeenCalledWith(
      {
        customer_name: "Alice",
        conversation_id: "conv-123"
      },
      { replace: false }
    );
    expect(apiCall).toHaveBeenNthCalledWith(2, "support.send_message", {
      text: "Hello from storefront",
      sender: "shopper",
      conversation_id: "conv-123"
    });
  });
});
