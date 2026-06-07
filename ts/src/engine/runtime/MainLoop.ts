import { cameraUpdate } from "../../../_generated/src/engine/Camera/Camera";
import { Component_update as animatorUpdate } from "../../../_generated/src/engine/Component/Animator";
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
let lastPerfMs = 0;

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

/** Camera.update expects ITransform with `position` and `scale` (generated Camera.ts:82). */
function ensureCameraTargetScale(cam: SceneCamera): void {
    const target = cam.target as { scale?: { x: number; y: number; z: number } } | null | undefined;
    if (!target) {
        return;
    }
    if (!target.scale) {
        target.scale = { x: 1, y: 1, z: 1 };
    }
}

type SceneSprite = {
    layer?: number;
    isStatic?: boolean;
};

/** Match Julia `render_scene_sprites_and_shapes`: draw by ascending `sprite.layer`. */
function spritesInLayerOrder(entities: SceneEntity[]): unknown[] {
    const items: { layer: number; sprite: unknown }[] = [];
    for (const entity of entities) {
        if (!entity.isActive || !entity.sprite) {
            continue;
        }
        const sprite = entity.sprite as SceneSprite;
        items.push({ layer: sprite.layer ?? 0, sprite: entity.sprite });
    }
    items.sort((a, b) => a.layer - b.layer);
    return items.map((item) => item.sprite);
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
        setColor(ui.color[0], ui.color[1], ui.color[2], ui.color[3]);
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
    const perfNow = performance.now();
    const sdlDelta = lastFrameMs === 0 ? 0 : (nowMs - lastFrameMs) / 1000;
    const perfDelta = lastPerfMs === 0 ? 0 : (perfNow - lastPerfMs) / 1000;
    lastFrameMs = nowMs;
    lastPerfMs = perfNow;
    const deltaTime = Math.max(sdlDelta, perfDelta);
    jg.DELTA_TIME = deltaTime;
    jg.FrameCount = (jg.FrameCount ?? 0) + 1;

    const input = M.input;
    if (input && jg.InputModule) {
        jg.InputModule.poll_input(input);
    }

    const scene = M.scene;
    const cam = scene.camera;

    if (!editorMode) {
        // Scripts set velocity first; rigidbody update applies it (Collider checks run inside Rigidbody.update).
        for (const entity of scene.entities) {
            if (entity.isActive) {
                JulGame_update(entity as never, deltaTime);
            }
        }
        tickCoroutines();
        for (const rb of scene.rigidbodies) {
            const body = rb as { parent?: { isActive?: boolean } } | null;
            if (!body?.parent?.isActive) {
                continue;
            }
            try {
                (rigidbodyUpdate as (r: unknown, dt: number) => void)(body, deltaTime);
            } catch (e) {
                console.error("rigidbody update failed", e);
            }
        }
        for (const entity of scene.entities) {
            if (entity.isActive && entity.animator) {
                (animatorUpdate as (a: unknown, t: number, dt: number) => void)(
                    entity.animator,
                    nowMs,
                    deltaTime,
                );
            }
        }
    }

    if (cam && input && jg.InputModule) {
        applyCameraFollow(cam, deltaTime);
        updateMouseWorld(input, cam, jg.pixels_per_world_unit);
    }

    (api.glue_SDL_RenderClear as () => void)();

    if (cam) {
        ensureCameraTargetScale(cam);
        (cameraUpdate as (c: unknown, p: null) => void)(cam, null);
    }

    for (const sprite of spritesInLayerOrder(scene.entities)) {
        (Component_draw as (s: unknown, c: unknown) => void)(sprite, cam);
    }

    if (cam && scene.uiElements?.length) {
        drawUiTextBoxes(api, scene.uiElements, cam);
    }

    (api.glue_SDL_RenderPresent as () => void)();
}
