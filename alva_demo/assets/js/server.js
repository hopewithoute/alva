import liveVueApp from "../vue";
import { getRender, loadManifest } from "live_vue/server";

const manifest = loadManifest("../priv/vue/.vite/ssr-manifest.json");
export const render = getRender(liveVueApp, manifest);
