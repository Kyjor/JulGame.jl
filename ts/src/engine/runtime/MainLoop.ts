import { cameraUpdate } from "../../../_generated/src/engine/Camera/Camera";
import { Component_update as animatorUpdate } from "../../../_generated/src/engine/Component/Animator";
import { Component_check_collisions } from "../../../_generated/src/engine/Component/Collider";
import { Component_update as rigidbodyUpdate } from "../../../_generated/src/engine/Component/Rigidbody";
import { Component_draw } from "../../../_generated/src/engine/Component/Sprite";
import { JulGame_update } from "../../../_generated/src/engine/Entity";
import type { SceneTextBox } from "./SceneBuilder";
import { tickCoroutines } from "./coroutineRuntime";
import type { TranspiledInput } from "./transpiledInput";

type SceneCamera = {
    position: { x: number; y: number; z: number };
    offset: { x: number; y: number };
    target?: { position: { x: number; y: number } } | null;
};

type SceneEntity = {
    isActive: boolean;
    sprite: unknown;
    animator: unknown;
    rigidbody: unknown;
    collider: unknown;
    scripts: unknown[];
};

type MainState = {
    scene: {
        camera: SceneCamera | null;
        entities: SceneEntity[];
        colliders: unknown[];
        rigidbodies: unknown[];
        uiElements: SceneTextBox[];
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

function applyCameraFollow(cam: SceneCamera, deltaTime: number): void {
    const target = cam.target;
    if (!target?.position) {
        return;
    }
    const lerp = Math.min(1, deltaTime * 8);
    cam.position.x += (target.position.x - cam.position.x) * lerp;
    cam.position.y += (target.position.y - cam.position.y) * lerp;
}

function drawUiTextBoxes(
    api: Record<string, unknown>,
    uiElements: SceneTextBox[],
    cam: SceneCamera | null,
): void {
    const setColor = api.glue_SDL_SetRenderDrawColor as (r: number, g: number, b: number, a: number) => void;
    const fillRect = api.glue_SDL_RenderFillRectF as (x: number, y: number, w: number, h: number) => void;
    if (!setColor || !fillRect) {
        return;
    }
    for (const ui of uiElements) {
        if (!ui.isActive) {
            continue;
        }
        setColor(255, 255, 255, ui.alpha);
        let x = ui.position.x;
        if (ui.isCenteredX && cam) {
            x -= ui.size.x / 2;
        }
        fillRect(x, ui.position.y, Math.max(8, ui.text.length * 8), ui.size.y);
    }
}

/**
 * One SDL frame: input, physics, collisions, scripts, camera, sprites, UI, present.
 */
export function runStrippedGameFrame(): void {
    runGameFrame(false);
}

/** Full game loop frame (physics + scripts + coroutines). */
export function runGameFrame(editorMode = false): void {
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

    if (!editorMode) {
        for (const rb of scene.rigidbodies) {
            if (rb) {
                (rigidbodyUpdate as (r: unknown, dt: number) => void)(rb, deltaTime);
            }
        }
        for (const col of scene.colliders) {
            if (col) {
                (Component_check_collisions as (c: unknown) => void)(col);
            }
        }
        tickCoroutines();
        for (const entity of scene.entities) {
            if (entity.isActive) {
                JulGame_update(entity as never, deltaTime);
                if (entity.animator) {
                    (animatorUpdate as (a: unknown, t: number, dt: number) => void)(
                        entity.animator,
                        nowMs,
                        deltaTime,
                    );
                }
            }
        }
    }

    if (cam && input && jg.InputModule) {
        applyCameraFollow(cam, deltaTime);
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

    if (cam && scene.uiElements?.length) {
        drawUiTextBoxes(api, scene.uiElements, cam);
    }

    (api.glue_SDL_RenderPresent as () => void)();
}
