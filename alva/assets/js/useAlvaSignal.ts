import { onUnmounted } from "vue";
import { useLiveEvent } from "live_vue";
import { useAlvaSubscriptions } from "./useAlvaSubscriptions";
import type { AlvaSubscriptionDef } from "./useAlvaSubscriptions";

export function useAlvaSignal<
    Subs extends Record<string, AlvaSubscriptionDef> = any,
    S extends keyof Subs = keyof Subs
>(
    name: S,
    input: Subs[S]["input"],
    callback: (payload: Subs[S]["payload"]) => void
) {
    const subs = useAlvaSubscriptions<Subs>();
    
    // Activate the subscription on the backend
    // We ignore the returned promise because signals are fire-and-forget
    // and if it fails, there's no data to fall back on anyway.
    // Error handling can be added later if needed.
    subs.activate(name, input);

    // Register the LiveView event listener for the pushed notifications
    // Assuming backend pushes event with the same name as the signal
    const unregister = useLiveEvent(name as string, callback);

    onUnmounted(() => {
        unregister();
        subs.deactivate(name, input);
    });
}
