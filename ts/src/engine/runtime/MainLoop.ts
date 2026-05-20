import { cameraUpdate } from "../../../_generated/src/engine/Camera/Camera";
import { Component_draw } from "../../../_generated/src/engine/Component/Sprite";

/**
 * One SDL frame: clear, camera background, world sprites, present.
 * Does not use generated `MainLoop.ts`, WindowManager, TextBox, or Input.
 */
export function runStrippedGameFrame(): void {
    const M = (globalThis as unknown as { MAIN: { scene: { camera: unknown; entities: Iterable<{ isActive: boolean; sprite: unknown }> } } }).MAIN;
    const api = (globalThis as unknown as { JulGameSdl: Record<string, unknown> }).JulGameSdl;

    (api.glue_SDL_RenderClear as () => void)();

    const scene = M.scene;
    const cam = scene.camera;
    if (cam) {
        (cameraUpdate as (c: unknown, p: null) => void)(cam, null);
    }

    for (const e of scene.entities) {
        if (e.isActive && e.sprite) {
            (Component_draw as (s: unknown, c: unknown) => void)(e.sprite, cam);
        }
    }

    (api.glue_SDL_RenderPresent as () => void)();
}
