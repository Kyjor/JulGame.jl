import { defineConfig } from "vite";

export default defineConfig({
  base: "./",
  assetsInclude: ["**/*.wasm"],
  optimizeDeps: {
    exclude: ["src/platform/sdl-wasm/julgame.js"],
  },
});
