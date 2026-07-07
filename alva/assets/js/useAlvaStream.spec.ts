import { describe, it, expect, vi, beforeEach } from 'vitest';
import { useAlvaStream } from './useAlvaStream';
import * as useAlvaSubscriptions from './useAlvaSubscriptions';

// Mock dependencies
vi.mock('vue', () => ({
    ref: (val: any) => ({ value: val }),
    computed: (fn: any) => ({ get value() { return fn(); } }),
    onUnmounted: vi.fn((fn) => {
        // Expose for testing
        (globalThis as any)._unmountCallback = fn;
    })
}));

vi.mock('./useAlvaSubscriptions', () => ({
    useAlvaSubscriptions: vi.fn()
}));

describe('useAlvaStream', () => {
    let mockActivate: any;
    let mockDeactivate: any;

    beforeEach(() => {
        vi.clearAllMocks();
        delete (globalThis as any)._unmountCallback;

        mockActivate = vi.fn().mockResolvedValue({ ok: true });
        mockDeactivate = vi.fn().mockResolvedValue({ ok: true });

        vi.mocked(useAlvaSubscriptions.useAlvaSubscriptions).mockReturnValue({
            activate: mockActivate,
            deactivate: mockDeactivate
        } as any);
    });

    it('suppresses isLoading and skips activate when eager data is present', () => {
        const streamData = { fake: "data" };
        const { isLoading, error } = useAlvaStream('students', {}, streamData);

        expect(isLoading.value).toBe(false);
        expect(error.value).toBeNull();
        expect(mockActivate).not.toHaveBeenCalled();
    });

    it('sets isLoading and calls activate when eager data is absent', () => {
        const { isLoading, error } = useAlvaStream('students', {});

        // Since it's synchronous in the test setup, it immediately calls activate
        // and isLoading will be true until the promise resolves.
        expect(isLoading.value).toBe(true);
        expect(error.value).toBeNull();
        expect(mockActivate).toHaveBeenCalledWith('students', {});
    });

    it('calls deactivate on unmount', () => {
        useAlvaStream('students', {});
        
        // Trigger unmount
        (globalThis as any)._unmountCallback();

        expect(mockDeactivate).toHaveBeenCalledWith('students', {});
    });
});
