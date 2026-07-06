import { flushPromises, mount } from "@vue/test-utils";
import { beforeEach, describe, expect, it, vi } from "vitest";

import MerchantConsolePage from "./MerchantConsolePage.vue";

const { apiCall, uploadMock } = vi.hoisted(() => {
  return {
    apiCall: vi.fn(),
    uploadMock: {
      progress: undefined as any,
      files: undefined as any,
      showFilePicker: vi.fn(),
      clear: vi.fn(),
      getFileReferences: vi.fn(() => [])
    }
  };
});

vi.mock("alva", async () => {
  const { ref } = await import("vue");

  uploadMock.progress = ref(0);
  uploadMock.files = ref([]);

  return {
    ashUpload: () => uploadMock
  };
});

vi.mock("../js/alva/client", () => ({
  createAlvaApi: () => ({
    call: apiCall
  })
}));

vi.mock("./composables/useChatMessages", async () => {
  const { computed } = await import("vue");

  return {
    useChatMessages: (
      _activeConversationId: unknown,
      historicalMessages: { value: unknown[] }
    ) => computed(() => historicalMessages.value)
  };
});

const buildProps = () => ({
  sales_orders: [
    {
      id: "order-new",
      customer_name: "Alice",
      product_id: "product-mug",
      quantity: 1,
      lifecycle_status: "new",
      created_at: "2026-07-05T09:00:00Z",
      product: { name: "Alva Mug" }
    },
    {
      id: "order-processing",
      customer_name: "Bob",
      product_id: "product-lamp",
      quantity: 1,
      lifecycle_status: "processing",
      created_at: "2026-07-05T08:00:00Z",
      product: { name: "Alva Desk Lamp" }
    }
  ],
  products: [
    {
      id: "product-mug",
      name: "Alva Mug",
      description: "A sturdy ceramic mug.",
      media_reference: null,
      price: 1500,
      stock: 10
    },
    {
      id: "product-lamp",
      name: "Alva Desk Lamp",
      description: "A compact desk lamp.",
      media_reference: null,
      price: 6400,
      stock: 50
    }
  ],
  conversations: [
    {
      id: "conv-waiting",
      customer_name: "Waiting Shopper",
      last_message_at: "2026-07-05T09:15:00Z",
      last_message_preview: "Need help with an order",
      last_message_sender: "shopper",
      message_count: 1,
      needs_merchant_reply: true
    },
    {
      id: "conv-replied",
      customer_name: "Resolved Shopper",
      last_message_at: "2026-07-05T08:30:00Z",
      last_message_preview: "Thanks again",
      last_message_sender: "merchant",
      message_count: 2,
      needs_merchant_reply: false
    }
  ],
  support_messages: []
});

const mountPage = () => {
  return mount(MerchantConsolePage, {
    props: buildProps() as never,
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
};

const isHidden = (style: string | undefined) => {
  return (style ?? "").includes("display: none");
};

describe("MerchantConsolePage tabs", () => {
  beforeEach(() => {
    vi.clearAllMocks();

    uploadMock.progress.value = 0;
    uploadMock.files.value = [];
    uploadMock.getFileReferences.mockReset();
    uploadMock.getFileReferences.mockReturnValue([]);
    uploadMock.clear.mockReset();
    uploadMock.clear.mockImplementation(() => {
      uploadMock.progress.value = 0;
      uploadMock.files.value = [];
    });

    apiCall.mockImplementation(async (event: string, payload?: Record<string, unknown>) => {
      if (event === "support.list_messages" && payload?.conversation_id === "conv-waiting") {
        return {
          ok: true,
          data: [
            {
              id: "msg-1",
              conversation_id: "conv-waiting",
              sender: "shopper",
              text: "Need help with an order"
            }
          ]
        };
      }

      return { ok: true, data: [] };
    });
  });

  it("defaults to the orders tab and exposes workflow badge counts", () => {
    const wrapper = mountPage();

    expect(wrapper.get('[data-testid="merchant-console-tab-orders"]').attributes("aria-selected")).toBe(
      "true"
    );
    expect(
      isHidden(wrapper.get('[data-testid="merchant-console-panel-orders"]').attributes("style"))
    ).toBe(false);
    expect(
      isHidden(wrapper.get('[data-testid="merchant-console-panel-inventory"]').attributes("style"))
    ).toBe(true);
    expect(
      isHidden(wrapper.get('[data-testid="merchant-console-panel-support"]').attributes("style"))
    ).toBe(true);

    expect(wrapper.get('[data-testid="merchant-console-tab-orders"]').text()).toContain("1");
    expect(wrapper.get('[data-testid="merchant-console-tab-inventory"]').text()).toContain("1");
    expect(wrapper.get('[data-testid="merchant-console-tab-support"]').text()).toContain("1");
  });

  it("preserves order filter input across tab switches", async () => {
    const wrapper = mountPage();

    await wrapper
      .get('[data-testid="merchant-order-customer-query"]')
      .setValue("Alice");

    await wrapper.get('[data-testid="merchant-console-tab-inventory"]').trigger("click");
    await wrapper.get('[data-testid="merchant-console-tab-orders"]').trigger("click");

    expect(
      (wrapper.get('[data-testid="merchant-order-customer-query"]').element as HTMLInputElement)
        .value
    ).toBe("Alice");
  });

  it("filters orders from collection props without querying orders again", async () => {
    const wrapper = mountPage();

    await wrapper
      .get('[data-testid="merchant-order-customer-query"]')
      .setValue("Alice");

    const ordersPanel = wrapper.get('[data-testid="merchant-console-panel-orders"]');

    expect(ordersPanel.text()).toContain("Alice");
    expect(ordersPanel.text()).not.toContain("Bob");
    expect(apiCall.mock.calls.some(([event]) => event === "sales.list_orders")).toBe(
      false
    );
  });

  it("filters inventory and conversations from collection props without querying those lists again", async () => {
    const wrapper = mountPage();

    await wrapper.get('[data-testid="merchant-console-tab-inventory"]').trigger("click");
    await wrapper.get('[data-testid="merchant-inventory-query"]').setValue("Lamp");

    const inventoryPanel = wrapper.get('[data-testid="merchant-console-panel-inventory"]');

    expect(inventoryPanel.text()).toContain("Alva Desk Lamp");
    expect(inventoryPanel.text()).not.toContain("Alva Mug");

    await wrapper.get('[data-testid="merchant-console-tab-support"]').trigger("click");
    await wrapper.get('[data-testid="merchant-conversation-query"]').setValue("Resolved");

    const supportPanel = wrapper.get('[data-testid="merchant-console-panel-support"]');

    expect(supportPanel.text()).toContain("Resolved Shopper");
    expect(supportPanel.text()).not.toContain("Waiting Shopper");
    expect(apiCall.mock.calls.some(([event]) => event === "catalog.list_products")).toBe(
      false
    );
    expect(
      apiCall.mock.calls.some(([event]) => event === "support.list_conversations")
    ).toBe(false);
  });

  it("preserves selected conversation and draft reply across tab switches", async () => {
    const wrapper = mountPage();

    await wrapper.get('[data-testid="merchant-console-tab-support"]').trigger("click");
    await wrapper
      .get('[data-testid="merchant-conversation-conv-waiting"]')
      .trigger("click");
    await flushPromises();

    expect(apiCall).toHaveBeenCalledWith("support.list_messages", {
      conversation_id: "conv-waiting"
    });
    expect(wrapper.text()).toContain("Chatting with Waiting Shopper");

    await wrapper.get('[data-testid="merchant-reply-input"]').setValue("On it, checking now.");

    await wrapper.get('[data-testid="merchant-console-tab-orders"]').trigger("click");
    await wrapper.get('[data-testid="merchant-console-tab-support"]').trigger("click");
    await flushPromises();

    expect(wrapper.text()).toContain("Chatting with Waiting Shopper");
    expect(
      (wrapper.get('[data-testid="merchant-reply-input"]').element as HTMLInputElement).value
    ).toBe("On it, checking now.");
  });

  it("shows upload progress and submits product media when the upload completes", async () => {
    const wrapper = mountPage();
    const uploadedFile = { name: "mug.jpg" };

    await wrapper.get('[data-testid="merchant-console-tab-inventory"]').trigger("click");
    await wrapper.get('[data-testid="merchant-upload-media-product-mug"]').trigger("click");

    expect(uploadMock.showFilePicker).toHaveBeenCalledTimes(1);
    expect(wrapper.get('[data-testid="merchant-upload-media-product-mug"]').text()).toBe(
      "Uploading..."
    );

    uploadMock.progress.value = 45;
    await flushPromises();

    expect(
      wrapper.get('[data-testid="merchant-upload-progress-bar-product-mug"]').attributes("style")
    ).toContain("width: 45%");

    uploadMock.files.value = [uploadedFile];
    uploadMock.getFileReferences.mockReturnValue([uploadedFile]);
    uploadMock.progress.value = 100;
    await flushPromises();

    expect(apiCall).toHaveBeenCalledWith("catalog.upload_media", {
      id: "product-mug",
      media: uploadedFile
    });
    expect(uploadMock.clear).toHaveBeenCalledTimes(1);
    expect(wrapper.get('[data-testid="merchant-upload-media-product-mug"]').text()).toBe(
      "Upload Media"
    );
  });

  it("surfaces upload failures and clears the pending upload state", async () => {
    const wrapper = mountPage();
    const uploadedFile = { name: "broken-upload.jpg" };

    apiCall.mockImplementation(async (event: string, payload?: Record<string, unknown>) => {
      if (event === "catalog.upload_media") {
        throw new Error("Upload pipeline unavailable");
      }

      if (event === "support.list_messages" && payload?.conversation_id === "conv-waiting") {
        return {
          ok: true,
          data: [
            {
              id: "msg-1",
              conversation_id: "conv-waiting",
              sender: "shopper",
              text: "Need help with an order"
            }
          ]
        };
      }

      return { ok: true, data: [] };
    });

    await wrapper.get('[data-testid="merchant-console-tab-inventory"]').trigger("click");
    await wrapper.get('[data-testid="merchant-upload-media-product-mug"]').trigger("click");

    uploadMock.files.value = [uploadedFile];
    uploadMock.getFileReferences.mockReturnValue([uploadedFile]);
    uploadMock.progress.value = 100;
    await flushPromises();

    expect(wrapper.text()).toContain("Failed to upload media: Upload pipeline unavailable");
    expect(uploadMock.clear).toHaveBeenCalledTimes(1);
    expect(wrapper.get('[data-testid="merchant-upload-media-product-mug"]').text()).toBe(
      "Upload Media"
    );
  });
});
