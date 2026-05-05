import type { Platform } from "../../engine/platform/Platform";
import type { RenderCommand } from "../../engine/rendering/RenderCommands";
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
        this.setStatus("sdl-wasm: TS frame loop (square demo)");
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
            api.glue_render_square_frame();
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
