import type { RenderCommand } from "../engine/rendering/RenderCommands";

export type GameMain = {
    tick(elapsedMs: number): RenderCommand[];
};

export function createGameMain(): GameMain {
    return {
        tick(elapsedMs: number): RenderCommand[] {
            const t = elapsedMs / 1000;
            const r = Math.floor(40 + Math.sin(t) * 20);
            const g = Math.floor(80 + Math.sin(t * 1.7) * 30);
            const b = Math.floor(130 + Math.sin(t * 1.2) * 25);
            return [{ kind: "clear", color: `rgb(${r}, ${g}, ${b})` }];
        },
    };
}
