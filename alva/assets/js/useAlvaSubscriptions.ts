import { onScopeDispose } from "vue";
import { useLiveVue } from "live_vue";
import type { AlvaResult } from "./useAlvaApi";

export interface AlvaSubscriptionDef {
    kind: "stream" | "signal";
    input: Record<string, any>;
    payload?: any;
    item?: any;
}

interface ActiveSubscription {
    name: string;
    input: Record<string, any>;
    refCount: number;
}

// Track whether the current page has completed its first LiveView load.
// Hooks mounted after that point should treat the next `kind: initial` event
// as reconnect healing, while hooks mounted before it should not replay
// subscriptions during the first load event.
let pageInitialLoadComplete = false;

export function useAlvaSubscriptions<
    Subs extends Record<string, AlvaSubscriptionDef> = any,
>() {
    const live = useLiveVue();
    const localSubscriptions = new Map<string, ActiveSubscription>();
    let sawInitialLoadForHook = pageInitialLoadComplete;

    const replayLocalSubscriptions = () => {
        for (const sub of localSubscriptions.values()) {
            live.pushEvent(
                "alva:activate_subscription",
                { name: sub.name, input: sub.input },
                () => {}
            );
        }
    };

    const onReconnect = (info: any) => {
        if (info.detail?.kind !== "initial") {
            return;
        }

        if (!sawInitialLoadForHook) {
            sawInitialLoadForHook = true;
            pageInitialLoadComplete = true;
            return;
        }

        replayLocalSubscriptions();
    };

    if (typeof window !== "undefined") {
        window.addEventListener("phx:page-loading-stop", onReconnect);
        onScopeDispose(() => {
            window.removeEventListener("phx:page-loading-stop", onReconnect);
        });
    }

    const activate = <S extends keyof Subs>(
        name: S,
        input: Subs[S]["input"]
    ): Promise<AlvaResult<{ key: any; topics: string[] }>> => {
        const cacheKey = `${String(name)}:${JSON.stringify(input)}`;

        const existing = localSubscriptions.get(cacheKey);
        if (existing) {
            existing.refCount++;
        } else {
            localSubscriptions.set(cacheKey, {
                name: String(name),
                input,
                refCount: 1
            });
        }

        return new Promise((resolve) => {
            live.pushEvent(
                "alva:activate_subscription",
                { name: name as string, input },
                (reply: any) => {
                    resolve(reply);
                }
            );
        });
    };

    const loadMore = <S extends keyof Subs>(
        name: S,
        input: Subs[S]["input"]
    ): Promise<AlvaResult<{ key: any; topics: string[] }>> => {
        return new Promise((resolve) => {
            live.pushEvent(
                "alva:load_more_subscription",
                { name: name as string, input },
                (reply: any) => {
                    resolve(reply);
                }
            );
        });
    };

    const deactivate = <S extends keyof Subs>(
        name: S,
        input: Subs[S]["input"]
    ): Promise<AlvaResult> => {
        const cacheKey = `${String(name)}:${JSON.stringify(input)}`;

        const existing = localSubscriptions.get(cacheKey);
        if (existing) {
            existing.refCount--;
            if (existing.refCount <= 0) {
                localSubscriptions.delete(cacheKey);
            }
        }

        return new Promise((resolve) => {
            live.pushEvent(
                "alva:deactivate_subscription",
                { name: name as string, input },
                (reply: any) => {
                    resolve(reply);
                }
            );
        });
    };

    return { activate, deactivate, loadMore };
}
