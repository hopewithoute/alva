import type { LiveSocket } from "phoenix_live_view";

declare module "phoenix_live_view" {
  export interface LiveSocketInstanceInterface extends LiveSocket {}
  export type ViewHook = ViewHookInterface;
  export interface ViewHookInterface {
    /* eslint-disable-next-line @typescript-eslint/no-explicit-any */
    vue?: any;
  }
}
