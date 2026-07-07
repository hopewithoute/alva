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

// Global registry for healing subscriptions across reconnects
const activeSubscriptions = new Map<string, ActiveSubscription>();
let isListeningToReconnect = false;
let initialLoadComplete = false;

export function useAlvaSubscriptions<
    Subs extends Record<string, AlvaSubscriptionDef> = any,
>() {
    const live = useLiveVue();

    // Setup reconnection healing once
    if (!isListeningToReconnect && typeof window !== 'undefined') {
        isListeningToReconnect = true;
        
        window.addEventListener("phx:page-loading-stop", (info: any) => {
            if (info.detail?.kind === 'initial') {
                if (initialLoadComplete) {
                    // This is a reconnect! Heal all active subscriptions
                    for (const sub of activeSubscriptions.values()) {
                        live.pushEvent(
                            "alva:activate_subscription",
                            { name: sub.name, input: sub.input },
                            () => {}
                        );
                    }
                } else {
                    initialLoadComplete = true;
                }
            }
        });
    }

    const activate = <S extends keyof Subs>(
        name: S,
        input: Subs[S]["input"]
    ): Promise<AlvaResult<{ key: any; topics: string[] }>> => {
        const cacheKey = `${String(name)}:${JSON.stringify(input)}`;
        
        const existing = activeSubscriptions.get(cacheKey);
        if (existing) {
            existing.refCount++;
        } else {
            activeSubscriptions.set(cacheKey, {
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
        
        const existing = activeSubscriptions.get(cacheKey);
        if (existing) {
            existing.refCount--;
            if (existing.refCount <= 0) {
                activeSubscriptions.delete(cacheKey);
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
