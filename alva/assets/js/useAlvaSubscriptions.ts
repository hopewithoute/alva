import { useLiveVue } from "live_vue";
import type { AlvaResult } from "./useAlvaApi";

export interface AlvaSubscriptionDef {
    kind: "stream" | "signal";
    input: Record<string, any>;
    payload?: any;
    item?: any;
}

export function useAlvaSubscriptions<
    Subs extends Record<string, AlvaSubscriptionDef> = any,
>() {
    const live = useLiveVue();

    const activate = <S extends keyof Subs>(
        name: S,
        input: Subs[S]["input"]
    ): Promise<AlvaResult<{ key: any; topics: string[] }>> => {
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

    return { activate };
}
