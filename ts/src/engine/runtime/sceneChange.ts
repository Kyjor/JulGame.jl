import type { JulGameSdlApi } from "../../platform/sdl-wasm/SDLBridge";
import type { Scene } from "../../../_generated/src/engine/Scene";
import type { Entity } from "../../../_generated/src/engine/Entity";
import { cleanupCoroutines } from "./coroutineRuntime";
import { playSoundsOnStart, reloadEntitySounds } from "./memfsAudio";
import { clearUiTextTextureCache } from "./strippedUiText";
import {
    mergeStrippedSceneData,
    type SceneJson,
    type SceneTextBox,
    type StrippedSceneLoadOptions,
} from "./SceneBuilder";
import { destroyEntity, initializeAllScripts, shutdownAllScripts } from "./scriptLoader";

type EmMod = { FS?: { mkdirTree: (p: string) => void; writeFile: (p: string, data: Uint8Array) => void } };

export type StrippedSceneRuntime = StrippedSceneLoadOptions & {
    scenesBaseUrl: string;
    sceneJsonUrl: string;
    emscriptenModule: EmMod;
    api: JulGameSdlApi;
    pendingSceneFileName: string | null;
};

type MainLoopState = {
    scene: Scene;
    shouldChangeScene?: boolean;
};

let runtime: StrippedSceneRuntime | null = null;
let loadPromise: Promise<void> | null = null;

export function installStrippedSceneRuntime(config: StrippedSceneRuntime): void {
    runtime = config;
    const main = (globalThis as unknown as { MAIN: MainLoopState }).MAIN;
    main.shouldChangeScene = false;
    const jg = (globalThis as unknown as { JulGame: Record<string, unknown> }).JulGame;
    jg.change_scene = requestChangeScene;
}

/** Port of `JulGame.change_scene` — sync teardown; load happens on next frame(s). */
export function requestChangeScene(sceneFileName: string): void {
    if (!runtime) {
        console.warn(`change_scene("${sceneFileName}") — stripped scene runtime not installed`);
        return;
    }
    const root = globalThis as unknown as {
        MAIN: MainLoopState;
        JulGame: Record<string, unknown>;
    };
    const main = root.MAIN;
    const jg = root.JulGame;
    jg.IS_CHANGING_SCENE = true;
    console.debug(`Changing scene to: ${sceneFileName}`);

    teardownForSceneChange(main.scene);
    purgeUnusedTextureCache(runtime.api, main.scene);
    cleanupCoroutines();
    clearUiTextTextureCache(runtime.api);

    runtime.pendingSceneFileName = sceneFileName;
    main.shouldChangeScene = true;
    jg.IS_CHANGING_SCENE = false;
}

/**
 * Call once per frame before `runGameFrame`. Returns true while a scene change is in progress
 * (skip the normal game frame, matching Julia's early return from `game_loop`).
 */
export function tickSceneChange(): boolean {
    const main = (globalThis as unknown as { MAIN: MainLoopState }).MAIN;
    if (!main.shouldChangeScene || !runtime?.pendingSceneFileName) {
        return false;
    }
    if (!loadPromise) {
        const fileName = runtime.pendingSceneFileName;
        loadPromise = loadAndMergeScene(fileName)
            .catch((e) => {
                console.error(`sceneChange: failed to load "${fileName}"`, e);
            })
            .finally(() => {
                loadPromise = null;
                main.shouldChangeScene = false;
                if (runtime) {
                    runtime.pendingSceneFileName = null;
                }
            });
    }
    return true;
}

/** Drop SDL textures for image paths no longer referenced by any remaining entity. */
function purgeUnusedTextureCache(api: JulGameSdlApi, scene: Scene): void {
    const inUse = new Set<string>();
    for (const entity of scene.entities as Entity[]) {
        const sp = entity.sprite as { imagePath?: string } | null;
        if (sp?.imagePath) {
            inUse.add(sp.imagePath);
        }
    }
    const jg = (globalThis as unknown as { JulGame?: { TEXTURE_CACHE?: Record<string, number> } }).JulGame;
    const cache = jg?.TEXTURE_CACHE;
    const destroy = api.glue_SDL_DestroyTexture;
    if (!cache || typeof destroy !== "function") {
        return;
    }
    for (const [path, tex] of Object.entries(cache)) {
        if (!inUse.has(path) && tex) {
            destroy(tex);
            delete cache[path];
        }
    }
}

function teardownForSceneChange(scene: Scene): void {
    const persistentEntities: Entity[] = [];
    const toDestroy: Entity[] = [];

    for (const entity of scene.entities as Entity[]) {
        if (entity.persistentBetweenScenes) {
            persistentEntities.push(entity);
            continue;
        }
        shutdownAllScripts([entity]);
        toDestroy.push(entity);
    }
    for (const entity of toDestroy) {
        destroyEntity(entity);
    }

    const persistentUI: SceneTextBox[] = [];
    for (const ui of scene.uiElements as SceneTextBox[]) {
        if (ui.persistentBetweenScenes) {
            persistentUI.push(ui);
        }
    }

    scene.entities = persistentEntities as never[];
    scene.uiElements = persistentUI as never[];
    scene.colliders = [];
    scene.rigidbodies = [];
    for (const entity of persistentEntities) {
        if (entity.collider) {
            scene.colliders.push(entity.collider);
        }
        if (entity.rigidbody) {
            scene.rigidbodies.push(entity.rigidbody);
        }
    }
    scene.batchedLayers = {};
    const cam = scene.camera as { target?: unknown } | null;
    if (cam) {
        cam.target = null;
    }
}

async function loadAndMergeScene(sceneFileName: string): Promise<void> {
    if (!runtime) {
        return;
    }
    const rt = runtime;
    const main = (globalThis as unknown as { MAIN: MainLoopState }).MAIN;
    const scene = main.scene;

    const sceneJsonUrl = new URL(sceneFileName, rt.scenesBaseUrl).href;
    console.info(`sceneChange: loading ${sceneJsonUrl}`);

    let json: SceneJson;
    const res = await fetch(sceneJsonUrl);
    if (!res.ok) {
        throw new Error(`fetch ${sceneJsonUrl} status ${res.status}`);
    }
    json = (await res.json()) as SceneJson;

    await mergeStrippedSceneData(scene, rt.emscriptenModule, json, {
        memfsAssetBaseUrl: rt.memfsAssetBaseUrl,
        canvasWidth: rt.canvasWidth,
        canvasHeight: rt.canvasHeight,
        loadScripts: true,
        deferScriptInitialize: true,
    });

    scene.name = sceneFileName.replace(/\.json$/i, "");
    rt.sceneJsonUrl = sceneJsonUrl;

    initializeAllScripts(scene.entities as Entity[]);
    reloadEntitySounds(scene);
    playSoundsOnStart(scene);
    applyLogicalSize(rt.api, rt.canvasWidth, rt.canvasHeight, scene);
}

function applyLogicalSize(
    api: JulGameSdlApi,
    canvasWidth: number,
    canvasHeight: number,
    scene: Scene,
): void {
    const cam = scene.camera as { size?: { x: number; y: number } } | null;
    if (cam?.size && cam.size.x > 0 && cam.size.y > 0) {
        const w = Math.floor(cam.size.x);
        const h = Math.floor(cam.size.y);
        if (w !== canvasWidth || h !== canvasHeight) {
            api.glue_SDL_RenderSetLogicalSize(w, h);
        } else {
            api.glue_SDL_RenderSetLogicalSize(0, 0);
        }
    } else {
        api.glue_SDL_RenderSetLogicalSize(0, 0);
    }
}
