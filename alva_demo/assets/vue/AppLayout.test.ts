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
    expect(navText).not.toContain("Chat Demo");
    expect(navText).not.toContain("Signals Demo");
    expect(navText).not.toContain("Load More Demo");
    expect(wrapper.html()).toContain('href="/storefront"');
    expect(wrapper.html()).toContain('href="/console"');
    expect(wrapper.html()).not.toContain('href="/demo/chat"');
    expect(wrapper.html()).not.toContain('href="/demo/notifications"');
    expect(wrapper.html()).not.toContain('href="/demo/load-more"');
  });
});
