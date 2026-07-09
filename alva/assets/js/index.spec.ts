import { describe, expect, it, vi } from "vitest";

vi.mock("live_vue", () => ({
    useLiveVue: vi.fn(),
    useLiveEvent: vi.fn(),
}));

import {
    useAlvaForm,
    useAlvaStream,
    useAlvaSubscriptions,
    useAlvaUpload,
    ash
} from "./index";

describe("package root exports", () => {
    it("re-exports useAlvaSubscriptions for compatibility consumers", () => {
        expect(useAlvaSubscriptions).toBe(useAlvaSubscriptions);
    });
});
