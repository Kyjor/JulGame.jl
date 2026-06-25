import path from "node:path";
import { defineConfig } from "vite";

const julgameRoot = path.resolve(__dirname, "{{JULGAME_TS_REL}}");

export default defineConfig({
    base: "./",
    root: ".",
    assetsInclude: ["**/*.wasm"],
    resolve: {
        alias: {
            julgame: julgameRoot,
        },
    },
    server: {
        port: {{DEV_PORT}},
        fs: {
            allow: [julgameRoot, path.resolve(__dirname, ".."), path.resolve(__dirname, "../..")],
        },
    },
    optimizeDeps: {
        exclude: ["julgame/src/platform/sdl-wasm/julgame.js"],
    },
});
