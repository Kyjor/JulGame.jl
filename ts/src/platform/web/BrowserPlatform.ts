import type { Platform } from "../../engine/platform/Platform";
import type { RenderCommand } from "../../engine/rendering/RenderCommands";

export class BrowserPlatform implements Platform {
    private readonly ctx: CanvasRenderingContext2D;

    constructor(
        private readonly canvas: HTMLCanvasElement,
        private readonly status: HTMLElement,
    ) {
        const ctx = this.canvas.getContext("2d");
        if (!ctx) throw new Error("Failed to acquire 2D context");
        this.ctx = ctx;
    }

    async init(): Promise<void> {
        this.setStatus("Backend: browser");
    }

    beginFrame(): void {}

    submit(commands: RenderCommand[]): void {
        for (const cmd of commands) {
            if (cmd.kind === "clear") {
                this.ctx.fillStyle = cmd.color;
                this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
            }
        }
    }

    endFrame(): void {}

    setStatus(text: string): void {
        this.status.textContent = text;
    }
}
