import path from "path"
import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
import liveVuePlugin from "live_vue/vitePlugin"

export default defineConfig(({ command }) => {
  const isDev = command !== "build"

  return {
    base: isDev ? undefined : "/assets",
    publicDir: "static",
    plugins: [vue(), liveVuePlugin()],
    resolve: {
      alias: {
        "@": path.resolve(__dirname, "."),
        "live_vue/server": path.resolve(__dirname, "node_modules/live_vue/assets/server.ts"),
        live_vue: path.resolve(__dirname, "node_modules/live_vue"),
        vue: path.resolve(__dirname, "node_modules/vue"),
      },
    },
    optimizeDeps: {
      include: ["live_vue", "phoenix", "phoenix_html", "phoenix_live_view"],
    },
    ssr: {
      noExternal: isDev ? undefined : true,
    },
    build: {
      commonjsOptions: { transformMixedEsModules: true },
      target: "es2020",
      outDir: "../priv/static/assets",
      emptyOutDir: true,
      sourcemap: isDev,
      rollupOptions: {
        input: {
          app: path.resolve(__dirname, "./js/app.js"),
        },
        output: {
          entryFileNames: "[name].js",
          chunkFileNames: "[name].js",
          assetFileNames: "[name][extname]",
        },
      },
    },
  }
})
