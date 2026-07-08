import { describe, expect, it, vi } from "vitest";

vi.mock("live_vue", () => ({
    useLiveVue: vi.fn(),
    useLiveEvent: vi.fn(),
}));

import * as alva from "./index";
import { useAlvaSubscriptions } from "./useAlvaSubscriptions";

describe("package root exports", () => {
    it("re-exports useAlvaSubscriptions for compatibility consumers", () => {
        expect(alva.useAlvaSubscriptions).toBe(useAlvaSubscriptions);
    });
});
