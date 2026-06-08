import { cameraUpdate } from "../../../_generated/src/engine/Camera/Camera";
import type { JulGameSdlApi } from "../../platform/sdl-wasm/SDLBridge";
import { Component_update as animatorUpdate } from "../../../_generated/src/engine/Component/Animator";
import { Component_update as rigidbodyUpdate } from "../../../_generated/src/engine/Component/Rigidbody";
import { Component_draw } from "../../../_generated/src/engine/Component/Sprite";
import { JulGame_update } from "../../../_generated/src/engine/Entity";
import { tickCoroutines } from "./coroutineRuntime";
import { flushUiDrawProfile } from "./uiDrawProfile";
import { initializeSceneUi, renderSceneUi, type UiDrawStats } from "./uiRender";
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
        uiElements: unknown[];
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
let sceneUiInitialized = false;

export function resetSceneUiInitialization(): void {
    sceneUiInitialized = false;
}

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

/**
 * One SDL frame: input, physics, collisions, scripts, camera, sprites, UI, present.
 */
export function runStrippedGameFrame(): void {
    runGameFrame(false);
}

/** Full game loop frame (physics + scripts + coroutines). */
export function runGameFrame(editorMode = false): void {
    const marks: Record<string, number> = {};
    const mark = (name: string) => {
        marks[name] = performance.now();
    };
    mark("start");

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
    mark("input");

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
    mark("scripts");

    if (cam && input && jg.InputModule) {
        applyCameraFollow(cam, deltaTime);
        updateMouseWorld(input, cam, jg.pixels_per_world_unit);
    }

    (api.glue_SDL_RenderClear as () => void)();

    if (cam) {
        ensureCameraTargetScale(cam);
        (cameraUpdate as (c: unknown, p: null) => void)(cam, null);
    }
    mark("camera");

    for (const sprite of spritesInLayerOrder(scene.entities)) {
        (Component_draw as (s: unknown, c: unknown) => void)(sprite, cam);
    }
    mark("sprites");

    let uiDrawStats: UiDrawStats | undefined = undefined;
    const g = globalThis as { __JULGAME_PROFILE_UI_DRAW?: boolean };
    if (g.__JULGAME_PROFILE_UI_DRAW !== false) {
        g.__JULGAME_PROFILE_UI_DRAW = true;
    }
    if (scene.uiElements?.length) {
        const sdlApi = api as JulGameSdlApi;
        if (!sceneUiInitialized) {
            initializeSceneUi(sdlApi, scene.uiElements);
            sceneUiInitialized = true;
        }
        mark("uiInit");
        uiDrawStats = renderSceneUi(sdlApi, scene.uiElements);
    } else {
        mark("uiInit");
    }
    mark("ui");
    if (g.__JULGAME_PROFILE_UI_DRAW && uiDrawStats !== undefined) {
        flushUiDrawProfile(marks.ui - marks.uiInit);
    }

    (api.glue_SDL_RenderPresent as () => void)();
    mark("end");

    const total = marks.end - marks.start;
    if (total > 16) {
        const seg = (from: string, to: string) => (marks[to] - marks[from]).toFixed(0);
        const uiDrawMs = marks.ui - marks.uiInit;
        const uiSuffix =
            uiDrawStats !== undefined
                ? ` drawn=${uiDrawStats.drawn}(img${uiDrawStats.images}/btn${uiDrawStats.buttons}/txt${uiDrawStats.textBoxes})` +
                  ` skip=${uiDrawStats.skippedHidden}hidden+${uiDrawStats.skippedInactive}inactive` +
                  (uiDrawStats.settingsMenuDrawn > 0
                      ? ` WARN settingsDrawn=${uiDrawStats.settingsMenuDrawn}`
                      : "") +
                  (uiDrawStats.drawn > 0 ? ` ~${(uiDrawMs / uiDrawStats.drawn).toFixed(1)}ms/draw` : "")
                : "";
        console.log(
            `frame ${total.toFixed(0)}ms`,
            `input ${seg("start", "input")}`,
            `scripts ${seg("input", "scripts")}`,
            `camera ${seg("scripts", "camera")}`,
            `sprites ${seg("camera", "sprites")}`,
            `uiInit ${seg("sprites", "uiInit")}`,
            `uiDraw ${uiDrawMs.toFixed(0)}${uiSuffix}`,
            `present ${seg("ui", "end")}`,
        );
    }
}
