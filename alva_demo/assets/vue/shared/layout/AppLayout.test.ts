import { mount } from "@vue/test-utils";
import { describe, expect, it } from "vitest";

import AppLayout from "./AppLayout.vue";

describe("AppLayout", () => {
  it("limits the main navigation to the commerce showcase surfaces", () => {
    const wrapper = mount(AppLayout, {
      slots: {
        default: "<div>content</div>"
      },
      global: {
        stubs: {
          Link: {
            props: ["navigate"],
            template: '<a :href="navigate"><slot /></a>'
          }
        }
      }
    });

    const navText = wrapper.text();

    expect(navText).toContain("Customer Storefront");
    expect(navText).toContain("Merchant Console");
    expect(navText).toContain("Chat (Stream)");
    expect(navText).toContain("Infinite Scroll (Stream)");
    expect(navText).toContain("Toast (Global)");
    expect(wrapper.html()).toContain('href="/storefront"');
    expect(wrapper.html()).toContain('href="/console"');
    expect(wrapper.html()).toContain('href="/demo/chat"');
    expect(wrapper.html()).toContain('href="/demo/notifications"');
    expect(wrapper.html()).toContain('href="/demo/load-more"');
  });
});
