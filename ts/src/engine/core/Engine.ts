import type { Platform } from "../platform/Platform";
import type { GameMain } from "../../game/GameMain";

export class Engine {
    constructor(
        private readonly platform: Platform,
        private readonly game: GameMain,
    ) {}

    async start(): Promise<void> {
        await this.platform.init();
        const startedAt = performance.now();

        const frame = () => {
            const elapsedMs = performance.now() - startedAt;
            const commands = this.game.tick(elapsedMs);
            this.platform.beginFrame();
            this.platform.submit(commands);
            this.platform.endFrame();
            requestAnimationFrame(frame);
        };

        requestAnimationFrame(frame);
    }
}
