import { onUnmounted } from "vue";
import { useLiveVue, useLiveEvent } from "live_vue";

export type RegistryDef = Record<string, any>;

export const ash = {
    on: <
        R extends RegistryDef,
        K extends keyof R
    >(
        name: K,
        input: R[K]["input"],
        callback: (payload: R[K] extends { payload: infer P } ? P : never) => void
    ) => {
        const live = useLiveVue();

        // 1. Emit alva:subscribe_signal to the LiveView process
        live.pushEvent(
            "alva:subscribe_signal", 
            { name: name as string, input }, 
            () => {}
        );

        // 2. Register listener for the push event from the server
        useLiveEvent(name as string, callback);

        // 3. Auto cleanup on component unmount
        onUnmounted(() => {
            live.pushEvent(
                "alva:unsubscribe_signal", 
                { name: name as string, input }, 
                () => {}
            );
        });
    }
};
