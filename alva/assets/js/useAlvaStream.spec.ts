import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ref } from 'vue';
import { useAlvaStream } from './useAlvaStream';
import * as useAlvaSubscriptions from './useAlvaSubscriptions';

// Mock dependencies
vi.mock('vue', () => ({
    ref: (val: any) => ({ value: val, __v_isRef: true }),
    computed: (fn: any) => ({ get value() { return fn(); } }),
    isRef: (val: any) => Boolean(val && val.__v_isRef),
    watch: vi.fn((source, callback) => {
        (globalThis as any)._watcher = { source, callback };
    }),
    onUnmounted: vi.fn((fn) => {
        // Expose for testing
        (globalThis as any)._unmountCallback = fn;
    }),
    getCurrentInstance: vi.fn(() => (globalThis as any)._currentInstance)
}));

vi.mock('./useAlvaSubscriptions', () => ({
    useAlvaSubscriptions: vi.fn()
}));

describe('useAlvaStream', () => {
    let mockActivate: any;
    let mockDeactivate: any;
    let mockLoadMore: any;

    beforeEach(() => {
        vi.clearAllMocks();
        delete (globalThis as any)._unmountCallback;
        delete (globalThis as any)._currentInstance;
        delete (globalThis as any)._watcher;

        mockActivate = vi.fn().mockResolvedValue({ ok: true });
        mockDeactivate = vi.fn().mockResolvedValue({ ok: true });
        mockLoadMore = vi.fn().mockResolvedValue({ ok: true, data: { page: { limit: 10 } } });

        vi.mocked(useAlvaSubscriptions.useAlvaSubscriptions).mockReturnValue({
            activate: mockActivate,
            deactivate: mockDeactivate,
            loadMore: mockLoadMore
        } as any);
    });

    it('suppresses isLoading and skips activate when eager data is present', () => {
        const streamData = { fake: "data" };
        (globalThis as any)._currentInstance = { props: { students: streamData } };
        
        const { isLoading, error } = useAlvaStream('students', {});

        expect(isLoading.value).toBe(false);
        expect(error.value).toBeNull();
        expect(mockActivate).not.toHaveBeenCalled();
    });

    it('sets isLoading and calls activate when eager data is absent', () => {
        (globalThis as any)._currentInstance = { props: {} };
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

    it('reactivates when a ref input changes', () => {
        const input = ref({ status: 'new' });

        useAlvaStream('students', input as any);

        expect(mockActivate).toHaveBeenCalledWith('students', { status: 'new' });

        input.value = { status: 'processing' };
        (globalThis as any)._watcher.callback(
            JSON.stringify(input.value),
            JSON.stringify({ status: 'new' })
        );

        expect(mockDeactivate).toHaveBeenCalledWith('students', { status: 'new' });
        expect(mockActivate).toHaveBeenLastCalledWith('students', { status: 'processing' });
    });

    it('forwards loadMore calls without tearing down the active subscription', async () => {
        const stream = useAlvaStream('students', {});
        const params = { page: { limit: 10, offset: 0 } };

        const result = await stream.loadMore(params as any);

        expect(mockLoadMore).toHaveBeenCalledWith('students', params);
        expect(result).toEqual({ ok: true, data: { page: { limit: 10 } } });
        expect(mockDeactivate).not.toHaveBeenCalled();
    });
});
