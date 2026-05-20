import "../../engine/core/globalConstants";
import type { Platform } from "../../engine/platform/Platform";
import type { RenderCommand } from "../../engine/rendering/RenderCommands";
import { bootstrapJulGameSdl } from "../../engine/runtime/julGameBootstrap";
import { loadStrippedScene } from "../../engine/runtime/SceneBuilder";
import { runStrippedGameFrame } from "../../engine/runtime/MainLoop";
import type { Scene } from "../../../_generated/src/engine/Scene";
import { SDLBridge } from "./SDLBridge";

export class SDLPlatform implements Platform {
    private readonly bridge = new SDLBridge();
    private loopStarted = false;

    constructor(
        private readonly canvas: HTMLCanvasElement,
        private readonly status: HTMLElement,
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

        bootstrapJulGameSdl(api, this.canvas.width, this.canvas.height);

        const mod = this.bridge.getModule();
        const sceneUrl = new URL("../../../../test/projects/SmokeTest/scenes/scene.json", import.meta.url).href;
        const assetBase = new URL("../../../../test/projects/SmokeTest", import.meta.url).href;
        const main = (globalThis as unknown as { MAIN: { scene: Scene } }).MAIN;
        await loadStrippedScene(main.scene, mod, {
            sceneJsonUrl: sceneUrl,
            memfsAssetBaseUrl: assetBase,
            canvasWidth: this.canvas.width,
            canvasHeight: this.canvas.height,
            maxEntities: 96,
        });

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

        this.setStatus("sdl-wasm: stripped engine loop");
        this.startLoop(api);
    }

    private startLoop(api: ReturnType<SDLBridge["getApi"]>): void {
        if (this.loopStarted) return;
        this.loopStarted = true;

        const tick = (): void => {
            if (api.glue_poll_quit() !== 0) {
                this.setStatus("sdl-wasm: quit");
                return;
            }
            runStrippedGameFrame();
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
