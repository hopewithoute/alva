import { flushPromises, mount } from "@vue/test-utils";
import { beforeEach, describe, expect, it, vi } from "vitest";

import CustomerStorefrontPage from "./CustomerStorefrontPage.vue";

const { streamCalls } = vi.hoisted(() => ({
  streamCalls: [] as Array<{ name: string; input: unknown }>
}));

vi.mock("alva", async () => {
  const { ref } = await import("vue");

  return {
    useAlvaApi: () => ({
      call: vi.fn(),
      on: vi.fn()
    }),
    useAlvaStream: (name: string, input: unknown) => {
      streamCalls.push({ name, input });

      return {
        isLoading: ref(false),
        error: ref(null),
        loadMore: vi.fn()
      };
    }
  };
});

const mountPage = () =>
  mount(CustomerStorefrontPage, {
    props: {
      sales_orders: [],
      products: [],
      active_conversation_id: null,
      connected_customer_name: null,
      support_messages: []
    } as never,
    global: {
      stubs: {
        StorefrontHeader: { template: "<div />" },
        StorefrontProductCard: { template: "<div />" },
        CustomerOrderDrawer: { template: "<div />" },
        SupportChatWidget: { template: "<div />" }
      }
    }
  });

describe("CustomerStorefrontPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    streamCalls.length = 0;
  });

  it("derives stream activation input from the latest storefront props", async () => {
    const wrapper = mountPage();
    const byName = (name: string) => streamCalls.find((call) => call.name === name);

    expect(byName("products")?.input).toEqual({ sort: "name" });
    expect(typeof byName("sales_orders")?.input).toBe("function");
    expect(typeof byName("support_messages")?.input).toBe("function");
    expect((byName("sales_orders")?.input as () => unknown)()).toEqual({
      sort: "-created_at",
      customer_query: null,
      require_customer: true
    });

    await wrapper.setProps({
      connected_customer_name: "Alice",
      active_conversation_id: "conv-123"
    } as never);
    await flushPromises();

    expect((byName("sales_orders")?.input as () => unknown)()).toEqual({
      sort: "-created_at",
      customer_query: "Alice",
      require_customer: true
    });
    expect((byName("support_messages")?.input as () => unknown)()).toEqual({
      conversation_id: "conv-123"
    });
  });
});
