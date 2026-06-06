import { cameraUpdate } from "../../../_generated/src/engine/Camera/Camera";
import { Component_draw } from "../../../_generated/src/engine/Component/Sprite";
import type { TranspiledInput } from "./transpiledInput";

type SceneCamera = {
    position: { x: number; y: number; z: number };
    offset: { x: number; y: number };
};

type MainState = {
    scene: {
        camera: SceneCamera | null;
        entities: Iterable<{ isActive: boolean; sprite: unknown }>;
    };
    input: TranspiledInput | null;
};

type JulGameGlobals = {
    InputModule?: {
        poll_input: (input: TranspiledInput) => void;
        get_button_held_down: (input: TranspiledInput, button: string) => boolean;
    };
    pixels_per_world_unit: (camera: SceneCamera | null) => number;
    DELTA_TIME?: number;
    FrameCount?: number;
};

let lastFrameMs = 0;

function updateMouseWorld(
    input: TranspiledInput,
    cam: SceneCamera,
    pixelsPerWorldUnit: (camera: SceneCamera | null) => number,
): void {
    const cameraPosition = {
        x: cam.position.x + cam.offset.x,
        y: cam.position.y + cam.offset.y,
    };
    const S = pixelsPerWorldUnit(cam);
    input.mousePositionWorld = {
        x: (input.mousePosition.x + cameraPosition.x * S) / S,
        y: (input.mousePosition.y + cameraPosition.y * S) / S,
    };
}

function applyArrowCameraPan(
    input: TranspiledInput,
    cam: SceneCamera,
    deltaTime: number,
    inputModule: NonNullable<JulGameGlobals["InputModule"]>,
): void {
    const speed = 4 * deltaTime;
    let dx = 0;
    let dy = 0;
    if (inputModule.get_button_held_down(input, "Right")) {
        dx = speed;
    } else if (inputModule.get_button_held_down(input, "Left")) {
        dx = -speed;
    }
    if (inputModule.get_button_held_down(input, "Up")) {
        dy = speed;
    } else if (inputModule.get_button_held_down(input, "Down")) {
        dy = -speed;
    }
    if (dx !== 0 || dy !== 0) {
        cam.position.x += dx;
        cam.position.y += dy;
    }
}

/**
 * One SDL frame: transpiled input poll, camera, clear, world sprites, present.
 */
export function runStrippedGameFrame(): void {
    const root = globalThis as unknown as {
        MAIN: MainState;
        JulGame: JulGameGlobals;
        JulGameSdl: Record<string, unknown>;
    };
    const M = root.MAIN;
    const jg = root.JulGame;
    const api = root.JulGameSdl;

    const nowMs = (api.glue_SDL_GetTicks as () => number)();
    const deltaTime = lastFrameMs === 0 ? 0 : (nowMs - lastFrameMs) / 1000;
    lastFrameMs = nowMs;
    jg.DELTA_TIME = deltaTime;
    jg.FrameCount = (jg.FrameCount ?? 0) + 1;

    const input = M.input;
    if (input && jg.InputModule) {
        jg.InputModule.poll_input(input);
    }

    const scene = M.scene;
    const cam = scene.camera;
    if (cam && input && jg.InputModule) {
        applyArrowCameraPan(input, cam, deltaTime, jg.InputModule);
        updateMouseWorld(input, cam, jg.pixels_per_world_unit);
    }

    (api.glue_SDL_RenderClear as () => void)();

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
