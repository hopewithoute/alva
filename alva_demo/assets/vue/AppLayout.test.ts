import { mount } from "@vue/test-utils";
import { describe, expect, it } from "vitest";

import AppLayout from "./AppLayout.vue";

describe("AppLayout", () => {
  it("exposes the realtime demo routes in the main navigation", () => {
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
    expect(navText).toContain("Chat Demo");
    expect(navText).toContain("Signals Demo");
    expect(navText).toContain("Load More Demo");
    expect(wrapper.html()).toContain('href="/demo/chat"');
    expect(wrapper.html()).toContain('href="/demo/notifications"');
    expect(wrapper.html()).toContain('href="/demo/load-more"');
  });
});
