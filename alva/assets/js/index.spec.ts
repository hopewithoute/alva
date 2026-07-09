import { describe, expect, it, vi } from "vitest";

vi.mock("live_vue", () => ({
    useLiveVue: vi.fn(),
    useLiveEvent: vi.fn(),
}));

import * as alva from "./index";

import { ash } from "./ash";

describe("package root exports", () => {

    it("re-exports ash", () => {
        expect(alva.ash).toBe(ash);
    });
});
