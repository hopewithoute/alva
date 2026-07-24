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

    expect(navText).toContain("Case Study");
    expect(navText).toContain("Console");
    expect(navText).toContain("Documentation");
    expect(wrapper.html()).toContain('href="/storefront"');
    expect(wrapper.html()).toContain('href="/console"');
    expect(wrapper.html()).toContain('href="/docs"');
  });
});
