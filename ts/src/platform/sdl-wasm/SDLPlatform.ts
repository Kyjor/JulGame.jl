import "../../engine/core/globalConstants";
import type { Platform } from "../../engine/platform/Platform";
import type { RenderCommand } from "../../engine/rendering/RenderCommands";
import { bootstrapJulGameSdl } from "../../engine/runtime/julGameBootstrap";
import { installStrippedSceneRuntime, tickSceneChange } from "../../engine/runtime/sceneChange";
import { initializeAllScripts } from "../../engine/runtime/scriptLoader";
import { loadStrippedScene } from "../../engine/runtime/SceneBuilder";
import { unlockSceneAudio } from "../../engine/runtime/memfsAudio";
import { runGameFrame } from "../../engine/runtime/MainLoop";
import type { Scene } from "../../../_generated/src/engine/Scene";
import { SDLBridge } from "./SDLBridge";

export type ProjectConfig = {
    sceneJsonUrl: string;
    memfsAssetBaseUrl: string;
    basePath?: string;
    /** Default sprite PPU; falls back to 16 (Julia `PIXELS_PER_UNIT`). */
    pixelsPerUnit?: number;
};

export class SDLPlatform implements Platform {
    private readonly bridge = new SDLBridge();
    private loopStarted = false;

    constructor(
        private readonly canvas: HTMLCanvasElement,
        private readonly status: HTMLElement,
        private readonly project: ProjectConfig,
    ) {}

    async init(): Promise<void> {
        this.setStatus("sdl-wasm: loading…");
        await this.bridge.init(
            this.canvas,
            (text) => console.log(text),
            (text) => console.error(text),
        );
        const api = this.bridge.getApi();
        const code = api.glue_init(this.canvas.width, this.canvas.height);
        if (code !== 0) {
            throw new Error(`glue_init failed (code ${code})`);
        }

        bootstrapJulGameSdl(api, this.canvas.width, this.canvas.height, this.canvas, {
            basePath: this.project.basePath ?? "/game",
            pixelsPerUnit: this.project.pixelsPerUnit,
        });

        const mod = this.bridge.getModule();
        const main = (globalThis as unknown as { MAIN: { scene: Scene } }).MAIN;
        await loadStrippedScene(main.scene, mod, {
            sceneJsonUrl: this.project.sceneJsonUrl,
            memfsAssetBaseUrl: this.project.memfsAssetBaseUrl,
            canvasWidth: this.canvas.width,
            canvasHeight: this.canvas.height,
            loadScripts: true,
            deferScriptInitialize: false,
        });
        installStrippedSceneRuntime({
            sceneJsonUrl: this.project.sceneJsonUrl,
            scenesBaseUrl: new URL("./", this.project.sceneJsonUrl).href,
            memfsAssetBaseUrl: this.project.memfsAssetBaseUrl,
            canvasWidth: this.canvas.width,
            canvasHeight: this.canvas.height,
            emscriptenModule: mod,
            api,
            pendingSceneFileName: null,
        });
        const unlockAudio = (): void => {
            unlockSceneAudio(api, main.scene);
            this.setStatus("sdl-wasm: game loop");
        };
        this.setStatus("sdl-wasm: click canvas to enable audio");
        this.canvas.addEventListener("pointerdown", () => unlockAudio(), { once: true });

        const cam = main.scene.camera as { size?: { x: number; y: number } } | null;
        const cw = this.canvas.width;
        const ch = this.canvas.height;
        if (cam?.size && cam.size.x > 0 && cam.size.y > 0) {
            const w = Math.floor(cam.size.x);
            const h = Math.floor(cam.size.y);
            /* Same as canvas: leave logical scaling OFF (SDL can misbehave if set equal to window). */
            if (w !== cw || h !== ch) {
                api.glue_SDL_RenderSetLogicalSize(w, h);
            } else {
                api.glue_SDL_RenderSetLogicalSize(0, 0);
            }
        } else {
            api.glue_SDL_RenderSetLogicalSize(0, 0);
        }

        this.setStatus("sdl-wasm: game loop");
        this.canvas.tabIndex = 0;
        this.canvas.focus({ preventScroll: true });
        this.startLoop(api);
    }

    private startLoop(api: ReturnType<SDLBridge["getApi"]>): void {
        if (this.loopStarted) return;
        this.loopStarted = true;

        const tick = (): void => {
            try {
                if (tickSceneChange()) {
                    requestAnimationFrame(tick);
                    return;
                }
                runGameFrame();
            } catch (e) {
                console.error("sdl-wasm: runGameFrame failed", e);
            }
            const main = (globalThis as unknown as { MAIN?: { input?: { quit?: boolean } } }).MAIN;
            if (main?.input?.quit) {
                this.setStatus("sdl-wasm: quit");
                return;
            }
            requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
    }

    beginFrame(): void {}

    submit(_commands: RenderCommand[]): void {}

    endFrame(): void {}

    setStatus(text: string): void {
        this.status.textContent = text;
    }
}
