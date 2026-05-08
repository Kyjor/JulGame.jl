import "./src/engine/core/globalConstants";
import { Engine } from "./src/engine/core/Engine";
import { BrowserPlatform } from "./src/platform/web/BrowserPlatform";
import { SDLPlatform } from "./src/platform/sdl-wasm";
import { createGameMain } from "./src/game/GameMain";

function getRequiredElement<T extends Element>(id: string, ctor: { new (): T }): T {
    const el = document.getElementById(id);
    if (!(el instanceof ctor)) {
        throw new Error(`Missing #${id}`);
    }
    return el;
}

async function boot() {
    const canvas = getRequiredElement("canvas", HTMLCanvasElement);
    const status = getRequiredElement("status", HTMLElement);
    const url = new URL(window.location.href);
    const useSDL = url.searchParams.get("backend") !== "web";

    if (useSDL) {
        const platform = new SDLPlatform(canvas, status);
        await platform.init();
        return;
    }

    const platform = new BrowserPlatform(canvas, status);
    const engine = new Engine(platform, createGameMain());
    await engine.start();
}

boot().catch((err: unknown) => {
    console.error(err);
    const status = document.getElementById("status");
    if (status) {
        status.textContent = `Boot failed: ${String(err)}`;
    }
});

