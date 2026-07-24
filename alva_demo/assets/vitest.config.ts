import path from "path";
import { defineConfig } from "vitest/config";
import vue from "@vitejs/plugin-vue";

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "."),
      vue: path.resolve(__dirname, "node_modules/vue")
    }
  },
  server: {
    fs: {
      allow: ["..", "../.."]
    }
  },
  test: {
    environment: "jsdom",
    include: ["vue/**/*.test.ts"]
  }
});
