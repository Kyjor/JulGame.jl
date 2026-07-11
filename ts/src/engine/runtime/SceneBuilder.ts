import { Camera } from "../../../_generated/src/engine/Camera/Camera";
import {
    Entity,
    JulGame_add_animator,
    JulGame_add_collider,
    JulGame_add_rigidbody,
    JulGame_add_sound_source,
    JulGame_add_sprite,
} from "../../../_generated/src/engine/Entity";
import { Transform } from "../../../_generated/src/engine/Component/Transform";
import type { Scene } from "../../../_generated/src/engine/Scene";
import { attachDefaultCamera } from "./julGameBootstrap";
import { flushPendingImageFetches } from "./memfsImage";
import { invalidateTextureCachesForImagePath } from "./textureCache";
import type { JulGameSdlApi } from "../../platform/sdl-wasm/SDLBridge";
import { commaSeparatedAssetPath, normalizeAssetPath, resolveSpritePixelsPerUnit } from "./projectConfig";
import { initializeAllScripts, instantiateScripts } from "./scriptLoader";
import { getScriptSoundPaths } from "./scriptRegistry";
import { hydrateCanvasFromJson, type SceneCanvas } from "../../../_generated/src/engine/UI/Canvas";
import { hydrateUiImageFromJson } from "../../../_generated/src/engine/UI/UIImage";
import { hydrateRectangleFromJson } from "../../../_generated/src/engine/UI/Rectangle";
import { hydrateScreenButtonFromJson } from "../../../_generated/src/engine/UI/ScreenButton";
import {
    hydrateTextBoxFromJson,
    type TextBoxElement,
} from "../../../_generated/src/engine/UI/TextBox";
import type { JulGameUiElement } from "../../../_generated/src/engine/UI/uiTypes";
import { UI_align_to_anchor } from "../../../_generated/src/engine/UI/UIElement";

/** Minimal valid PNG (1×1) for MEMFS when project assets are missing locally. */
const PNG_1X1 = Uint8Array.from(atob("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="), (ch) => ch.charCodeAt(0));

/** Inline fallback when `sceneJsonUrl` fetch fails (single sprite entity). */
export const MINIMAL_STRIPPED_SCENE: SceneJson = {
    Entities: [
        {
            id: "1",
            name: "demo",
            isActive: true,
            scripts: [],
            components: [
                {
                    type: "Transform",
                    position: { x: 0, y: 0 },
                    scale: { x: 1, y: 1 },
                    rotation: 0,
                },
                {
                    type: "Sprite",
                    imagePath: "placeholder.png",
                    isFlipped: false,
                    crop: {},
                },
            ],
        },
    ],
};

export type StrippedSceneLoadOptions = {
    sceneJsonUrl: string;
    /** Basename of scene JSON (e.g. `title_scene.json`) — selects deferred preload sets. */
    sceneFileName?: string;
    /** HTTP base whose `/assets/...` are fetched into MEMFS under `/game/assets/`. */
    memfsAssetBaseUrl: string;
    canvasWidth: number;
    canvasHeight: number;
    /** When true, instantiate transpiled scripts after entities are built. */
    loadScripts?: boolean;
    /** When true, only attach script instances — call `initializeAllScripts` later (e.g. after audio unlock). */
    deferScriptInitialize?: boolean;
};

type EmMod = {
    FS?: {
        mkdirTree: (p: string) => void;
        writeFile: (p: string, d: Uint8Array) => void;
        analyzePath?: (p: string) => { exists: boolean };
    };
};

const MEMFS_FETCH_CONCURRENCY = 24;

function sceneFileNameFromUrl(sceneJsonUrl: string): string {
    try {
        return new URL(sceneJsonUrl).pathname.split("/").pop() ?? "";
    } catch {
        return "";
    }
}

function resolveSceneFileName(opts: StrippedSceneLoadOptions): string {
    return opts.sceneFileName ?? sceneFileNameFromUrl(opts.sceneJsonUrl);
}

/** Settings panel + runtime-only assets — lazy-loaded after the scene is interactive. */
function isDeferredUiAsset(ui: UIElementJson): boolean {
    return String(ui.name ?? "").includes("SettingsMenu_");
}

function addUiImagePaths(imagePaths: Set<string>, ui: UIElementJson): void {
    if (ui.type === "UIImage" && typeof ui.path === "string" && ui.path) {
        if (/^screen-/i.test(ui.path)) {
            return;
        }
        imagePaths.add(ui.path);
    }
    if (ui.type === "ScreenButton") {
        if (typeof ui.buttonUpSpritePath === "string" && ui.buttonUpSpritePath) {
            imagePaths.add(ui.buttonUpSpritePath);
        }
        if (typeof ui.buttonDownSpritePath === "string" && ui.buttonDownSpritePath) {
            imagePaths.add(ui.buttonDownSpritePath);
        }
    }
}

function writeMemfsFile(fs: NonNullable<EmMod["FS"]>, memPath: string, data: Uint8Array): void {
    const slash = memPath.lastIndexOf("/");
    if (slash > 0) {
        fs.mkdirTree(memPath.slice(0, slash));
    }
    fs.writeFile(memPath, data);
}

function memfsPathExists(fs: NonNullable<EmMod["FS"]>, memPath: string): boolean {
    if (!fs.analyzePath) {
        return false;
    }
    try {
        return fs.analyzePath(memPath).exists;
    } catch {
        return false;
    }
}

function memfsFileSize(fs: NonNullable<EmMod["FS"]>, memPath: string): number | null {
    try {
        const stat = (fs as { stat?: (path: string) => { size: number } }).stat?.(memPath);
        return stat?.size ?? null;
    } catch {
        return null;
    }
}

/** Allow deferred loads to replace 1×1 placeholders written for missing assets. */
function isMemfsPlaceholder(fs: NonNullable<EmMod["FS"]>, memPath: string): boolean {
    return memfsFileSize(fs, memPath) === PNG_1X1.byteLength;
}

function sdlApi(): JulGameSdlApi | null {
    return (globalThis as { JulGameSdl?: JulGameSdlApi }).JulGameSdl ?? null;
}

async function mapWithConcurrency<T>(
    items: Iterable<T>,
    concurrency: number,
    fn: (item: T) => Promise<void>,
): Promise<void> {
    const queue = [...items];
    if (queue.length === 0) {
        return;
    }
    const workerCount = Math.min(concurrency, queue.length);
    await Promise.all(
        Array.from({ length: workerCount }, async () => {
            while (queue.length > 0) {
                const item = queue.shift();
                if (item === undefined) {
                    break;
                }
                await fn(item);
            }
        }),
    );
}

async function fetchAssetBytes(url: string): Promise<Uint8Array> {
    const res = await fetch(url);
    if (!res.ok) {
        throw new Error(String(res.status));
    }
    return new Uint8Array(await res.arrayBuffer());
}

export type SceneJson = {
    Entities?: EntityJson[];
    Camera?: {
        size: { x: number; y: number };
        position: { x: number; y: number };
        offset?: { x: number; y: number };
        backgroundColor?: { r: number; g: number; b: number; a: number };
        zoom?: number;
    };
    UIElements?: UIElementJson[];
};

type EntityJson = {
    id: string | number;
    name: string;
    isActive?: boolean;
    persistentBetweenScenes?: boolean;
    scripts?: unknown[];
    components?: ComponentJson[];
};

type ComponentJson = {
    type: string;
    position?: { x: number; y: number };
    scale?: { x: number; y: number };
    rotation?: number;
    imagePath?: string;
    isFlipped?: boolean;
    crop?: { x?: number; y?: number; z?: number; t?: number };
    pixelsPerUnit?: number;
    layer?: number;
    isStatic?: boolean;
    tag?: string;
    offset?: { x: number; y: number };
    enabled?: boolean;
    size?: { x: number; y: number };
    isPlatformerCollider?: boolean;
    isTrigger?: boolean;
    drag?: number;
    mass?: number;
    useGravity?: boolean;
    animations?: Array<{
        animatedFPS: number;
        frames: Array<{ x: number; y: number; z: number; t: number }>;
        framePaths?: string[];
    }>;
    path?: string;
    channel?: number;
    volume?: number;
    isMusic?: boolean;
    playOnStart?: boolean;
};

type UIElementJson = {
    type: string;
    id?: string | number;
    name?: string;
    text?: string;
    fontSize?: number;
    fontPath?: string;
    path?: string;
    position?: { x: number; y: number };
    size?: { x: number; y: number };
    isActive?: boolean;
    alpha?: number;
    color?: { r: number; g: number; b: number; a: number } | Record<string, number>;
    persistentBetweenScenes?: boolean;
    isCenteredX?: boolean;
    isCenteredY?: boolean;
    isWorldEntity?: boolean;
    anchor?: string;
    anchorOffset?: { x: number; y: number };
    parent?: string | null;
    layer?: number;
    isFlipped?: boolean;
    buttonUpSpritePath?: string;
    buttonDownSpritePath?: string;
};

/** @deprecated Use `TextBoxElement` from transpiled TextBox.ts */
export type SceneTextBox = TextBoxElement;

export type SceneUiImage = import("../../../_generated/src/engine/UI/UIImage").UiImageElement;

function buildUiElementFromJson(ui: UIElementJson): JulGameUiElement | null {
    const raw = ui as Record<string, unknown>;
    if (ui.type === "TextBox") {
        return hydrateTextBoxFromJson(raw);
    }
    if (ui.type === "UIImage") {
        return hydrateUiImageFromJson(raw);
    }
    if (ui.type === "ScreenButton") {
        return hydrateScreenButtonFromJson(raw);
    }
    if (ui.type === "Canvas") {
        return hydrateCanvasFromJson(raw);
    }
    if (ui.type === "Rectangle") {
        return hydrateRectangleFromJson(raw);
    }
    return null;
}

function collectSceneAssetPaths(json: SceneJson, sceneFileName = ""): {
    imagePaths: Set<string>;
    soundPaths: Set<string>;
    fontPaths: Set<string>;
} {
    const imagePaths = new Set<string>();
    const soundPaths = new Set<string>();
    const fontPaths = new Set<string>();
    for (const ent of json.Entities ?? []) {
        if (ent.isActive === false) {
            continue;
        }
        for (const c of ent.components ?? []) {
            if (c.type === "Sprite" && typeof c.imagePath === "string") {
                imagePaths.add(c.imagePath);
            }
            if (c.type === "SoundSource" && typeof c.path === "string") {
                soundPaths.add(c.path);
            }
        }
    }
    for (const ui of json.UIElements ?? []) {
        if (ui.isActive === false) {
            continue;
        }
        if (ui.type === "TextBox" && typeof ui.fontPath === "string" && ui.fontPath) {
            fontPaths.add(normalizeAssetPath(ui.fontPath));
        }
        if (isDeferredUiAsset(ui)) {
            continue;
        }
        addUiImagePaths(imagePaths, ui);
    }
    for (const p of getScriptSoundPaths()) {
        soundPaths.add(p);
    }
    const jgBlock = (globalThis as {
        JulGame?: { getBlockingExtraSceneImagePaths?: (sceneFileName?: string) => string[] };
    }).JulGame;
    if (typeof jgBlock?.getBlockingExtraSceneImagePaths === "function") {
        for (const p of jgBlock.getBlockingExtraSceneImagePaths(sceneFileName)) {
            if (p) {
                imagePaths.add(p);
            }
        }
    }
    return { imagePaths, soundPaths, fontPaths };
}

function collectDeferredImagePaths(json: SceneJson, sceneFileName: string): Set<string> {
    const imagePaths = new Set<string>();
    for (const ui of json.UIElements ?? []) {
        if (!isDeferredUiAsset(ui)) {
            continue;
        }
        addUiImagePaths(imagePaths, ui);
    }
    const jg = (globalThis as {
        JulGame?: { getDeferredExtraSceneImagePaths?: (sceneFileName?: string) => string[] };
    }).JulGame;
    if (typeof jg?.getDeferredExtraSceneImagePaths === "function") {
        for (const p of jg.getDeferredExtraSceneImagePaths(sceneFileName)) {
            if (p) {
                imagePaths.add(p);
            }
        }
    }
    return imagePaths;
}

/** Fire-and-forget MEMFS sync — sprites/UI retry load once files arrive. */
export function scheduleBackgroundAssetsToMemfs(
    emscriptenModule: EmMod,
    imagePaths: Iterable<string>,
    memfsAssetBaseUrl: string,
): void {
    const paths = [...imagePaths];
    if (paths.length === 0) {
        return;
    }
    void syncAssetsToMemfs(emscriptenModule, new Set(paths), new Set(), new Set(), memfsAssetBaseUrl);
}

async function syncAssetsToMemfs(
    emscriptenModule: EmMod,
    imagePaths: Set<string>,
    soundPaths: Set<string>,
    fontPaths: Set<string>,
    memfsAssetBaseUrl: string,
): Promise<void> {
    const fs = emscriptenModule.FS;
    if (!fs) {
        console.warn("SceneBuilder: Emscripten FS not available; asset load may fail");
        return;
    }
    const base = memfsAssetBaseUrl.replace(/\/$/, "");
    const loadStarted = performance.now();

    if (imagePaths.size > 0) {
        fs.mkdirTree("/game/assets/images");
    }
    if (soundPaths.size > 0) {
        fs.mkdirTree("/game/assets/sounds");
    }
    if (fontPaths.size > 0) {
        fs.mkdirTree("/game/assets/fonts");
    }

    await Promise.all([
        mapWithConcurrency(imagePaths, MEMFS_FETCH_CONCURRENCY, async (rel) => {
            const memPath = `/game/assets/images/${rel}`;
            if (memfsPathExists(fs, memPath) && !isMemfsPlaceholder(fs, memPath)) {
                return;
            }
            const url = `${base}/assets/images/${rel}`;
            const hadPlaceholder = isMemfsPlaceholder(fs, memPath);
            try {
                const data = await fetchAssetBytes(url);
                writeMemfsFile(fs, memPath, data);
                const api = sdlApi();
                if (api && hadPlaceholder) {
                    invalidateTextureCachesForImagePath(rel, api);
                }
            } catch {
                if (!memfsPathExists(fs, memPath)) {
                    writeMemfsFile(fs, memPath, PNG_1X1);
                    console.warn(`SceneBuilder: using 1×1 placeholder for missing image: ${url}`);
                }
            }
        }),
        mapWithConcurrency(soundPaths, MEMFS_FETCH_CONCURRENCY, async (rel) => {
            const memPath = `/game/assets/sounds/${rel}`;
            if (memfsPathExists(fs, memPath)) {
                return;
            }
            const url = new URL(`assets/sounds/${rel}`, `${base}/`).href;
            try {
                const data = await fetchAssetBytes(url);
                writeMemfsFile(fs, memPath, data);
                console.debug(`SceneBuilder: synced sound ${rel} (${data.byteLength} bytes)`);
            } catch (e) {
                console.warn(`SceneBuilder: missing sound asset: ${url}`, e);
            }
        }),
        mapWithConcurrency(fontPaths, MEMFS_FETCH_CONCURRENCY, async (rel) => {
            const memPath = `/game/assets/fonts/${rel}`;
            if (memfsPathExists(fs, memPath)) {
                return;
            }
            const url = `${base}/assets/fonts/${rel}`;
            try {
                const data = await fetchAssetBytes(url);
                const jg = (globalThis as {
                    JulGame?: { FONT_CACHE?: Record<string, Uint8Array> };
                }).JulGame;
                if (jg?.FONT_CACHE) {
                    jg.FONT_CACHE[commaSeparatedAssetPath(rel)] = data;
                }
                writeMemfsFile(fs, memPath, data);
                console.debug(`SceneBuilder: synced font ${rel} (${data.byteLength} bytes)`);
            } catch (e) {
                console.warn(`SceneBuilder: missing font asset: ${url}`, e);
            }
        }),
    ]);

    console.debug(
        `SceneBuilder: synced ${imagePaths.size} images, ${soundPaths.size} sounds, ${fontPaths.size} fonts in ${Math.round(performance.now() - loadStarted)}ms`,
    );
}

function registerPhysics(scene: Scene, entity: Entity): void {
    if (entity.collider && !scene.colliders.includes(entity.collider)) {
        scene.colliders.push(entity.collider);
    }
    if (entity.rigidbody && !scene.rigidbodies.includes(entity.rigidbody)) {
        scene.rigidbodies.push(entity.rigidbody);
    }
}

function buildEntityFromJson(ent: EntityJson, scene: Scene): Entity | null {
    let transformComp: ComponentJson | null = null;
    const otherComps: ComponentJson[] = [];
    for (const c of ent.components ?? []) {
        if (c.type === "Transform") {
            transformComp = c;
        } else {
            otherComps.push(c);
        }
    }
    if (!transformComp) {
        console.debug(`SceneBuilder: skip entity ${ent.name} — no Transform`);
        return null;
    }

    const pos = transformComp.position ?? { x: 0, y: 0 };
    const sc = transformComp.scale ?? { x: 1, y: 1 };
    const rot = transformComp.rotation ?? 0;
    const tr = new Transform(
        { x: pos.x, y: pos.y, z: 0 },
        { x: sc.x, y: sc.y, z: 1 },
        { x: 0, y: 0, z: rot },
        null,
    );
    const entity = new Entity(ent.name, String(ent.id), tr, []);
    entity.isActive = ent.isActive !== false;
    entity.persistentBetweenScenes = !!ent.persistentBetweenScenes;
    entity.scripts = (ent.scripts ?? []) as never[];

    for (const c of otherComps) {
        if (c.type === "Sprite" && c.imagePath) {
            const cr = c.crop;
            const hasCrop =
                cr &&
                typeof cr.x === "number" &&
                typeof cr.y === "number" &&
                typeof cr.z === "number" &&
                typeof cr.t === "number" &&
                !(cr.x === 0 && cr.y === 0 && cr.z === 0 && cr.t === 0);
            const crop = hasCrop ? { x: cr!.x!, y: cr!.y!, z: cr!.z!, t: cr!.t! } : null;
            JulGame_add_sprite(entity, false, {
                imagePath: c.imagePath,
                crop,
                isFlipped: !!c.isFlipped,
                color: [255, 255, 255, 255],
                pixelsPerUnit: resolveSpritePixelsPerUnit(
                    c.pixelsPerUnit,
                    (globalThis as { JulGame?: { PIXELS_PER_UNIT?: number } }).JulGame?.PIXELS_PER_UNIT ?? 16,
                ),
                position: { x: 0, y: 0 },
                rotation: 0,
                layer: c.layer ?? 0,
                center: { x: 0.5, y: 0.5 },
                anchor: "center",
                offset: { x: 0, y: 0 },
                isStatic: !!c.isStatic,
            });
        } else if (c.type === "Collider") {
            JulGame_add_collider(entity, {
                size: c.size ?? { x: 1, y: 1 },
                offset: c.offset ?? { x: 0, y: 0 },
                tag: c.tag ?? "Default",
                isTrigger: !!c.isTrigger,
                isPlatformerCollider: !!c.isPlatformerCollider,
                enabled: c.enabled !== false,
            });
        } else if (c.type === "Rigidbody") {
            JulGame_add_rigidbody(entity, {
                mass: c.mass ?? 1,
                useGravity: c.useGravity !== false,
            });
            if (entity.rigidbody && typeof c.drag === "number") {
                entity.rigidbody.drag = c.drag;
            }
        } else if (c.type === "Animator" && c.animations) {
            JulGame_add_animator(entity, { animations: c.animations });
        } else if (c.type === "SoundSource" && c.path) {
            JulGame_add_sound_source(entity, {
                path: c.path,
                channel: c.channel ?? -1,
                volume: c.volume ?? 100,
                isMusic: !!c.isMusic,
                playOnStart: !!c.playOnStart,
            });
            // SDL load deferred until Mix_OpenAudio (pointerdown) — see reloadEntitySounds.
        }
    }

    registerPhysics(scene, entity);
    return entity;
}

/**
 * Apply already-parsed scene JSON (fetch separately or use `MINIMAL_STRIPPED_SCENE`).
 */
function applyCameraFromJson(scene: Scene, json: SceneJson, canvasWidth: number, canvasHeight: number): void {
    if (json.Camera) {
        const bg = json.Camera.backgroundColor;
        const cam = new Camera(
            { x: json.Camera.size.x, y: json.Camera.size.y },
            { x: json.Camera.position.x, y: json.Camera.position.y, z: 0 },
            { x: json.Camera.offset?.x ?? 0, y: json.Camera.offset?.y ?? 0 },
            null,
        );
        if (bg) {
            cam.backgroundColor = [bg.r, bg.g, bg.b, bg.a ?? 255];
        }
        if (typeof json.Camera.zoom === "number") {
            cam.zoom = json.Camera.zoom;
        }
        scene.camera = cam;
    } else {
        attachDefaultCamera(scene, canvasWidth, canvasHeight);
    }
}

export async function applyStrippedSceneData(
    scene: Scene,
    emscriptenModule: EmMod,
    json: SceneJson,
    opts: StrippedSceneLoadOptions,
): Promise<void> {
    const sceneFileName = resolveSceneFileName(opts);
    const { imagePaths, soundPaths, fontPaths } = collectSceneAssetPaths(json, sceneFileName);
    const deferredImages = collectDeferredImagePaths(json, sceneFileName);
    const jg = (globalThis as { JulGame?: Record<string, unknown> }).JulGame;
    if (jg) {
        jg.memfsAssetBaseUrl = opts.memfsAssetBaseUrl;
        jg.emscriptenModule = emscriptenModule;
    }
    await syncAssetsToMemfs(emscriptenModule, imagePaths, soundPaths, fontPaths, opts.memfsAssetBaseUrl);
    flushPendingImageFetches();

    scene.entities = [];
    scene.uiElements = [];
    scene.colliders = [];
    scene.rigidbodies = [];
    scene.batchedLayers = {};

    for (const ent of json.Entities ?? []) {
        const entity = buildEntityFromJson(ent, scene);
        if (entity) {
            scene.entities.push(entity);
        }
    }

    for (const ui of json.UIElements ?? []) {
        const built = buildUiElementFromJson(ui);
        if (built) {
            scene.uiElements.push(built as never);
        }
    }

    applyCameraFromJson(scene, json, opts.canvasWidth, opts.canvasHeight);
    resolveUiElementParents(scene.uiElements, scene.entities);
    alignLoadedScreenTextBoxes(scene.uiElements);

    if (opts.loadScripts !== false) {
        instantiateScripts(scene.entities);
        if (!opts.deferScriptInitialize) {
            initializeAllScripts(scene.entities);
        }
    }

    scheduleBackgroundAssetsToMemfs(emscriptenModule, deferredImages, opts.memfsAssetBaseUrl);
}

/** Port of `SceneReader` `id::Type` parent refs → live UI / entity instances. */
function resolveUiElementParents(uiElements: unknown[], entities: unknown[]): void {
    const uiById = new Map<string, unknown>();
    for (const ui of uiElements) {
        const id = (ui as { id?: string | number }).id;
        if (id != null && id !== "") {
            uiById.set(String(id), ui);
        }
    }
    const entityById = new Map<string, unknown>();
    for (const ent of entities) {
        const id = (ent as { id?: string | number }).id;
        if (id != null && id !== "") {
            entityById.set(String(id), ent);
        }
    }
    for (const ui of uiElements) {
        const el = ui as { parent?: unknown };
        const raw = el.parent;
        if (typeof raw !== "string" || raw === "") {
            continue;
        }
        const sep = raw.indexOf("::");
        if (sep < 0) {
            continue;
        }
        const parentId = raw.slice(0, sep);
        const parentType = raw.slice(sep + 2);
        if (parentType === "Entity") {
            const resolved = entityById.get(parentId);
            if (resolved) {
                el.parent = resolved;
            }
        } else {
            const resolved = uiById.get(parentId);
            if (resolved) {
                el.parent = resolved;
            }
        }
    }
}

function alignLoadedScreenTextBoxes(uiElements: unknown[]): void {
    for (const raw of uiElements) {
        const el = raw as SceneTextBox;
        if (el?.name && el.isWorldEntity === false && el.anchor?.current_state !== "none") {
            UI_align_to_anchor(el);
        }
    }
}

/**
 * Port of `SceneBuilder.deserialize_and_build_scene` — merge new scene JSON into the current
 * scene, keeping persistent entities/UI (by id).
 */
export async function mergeStrippedSceneData(
    scene: Scene,
    emscriptenModule: EmMod,
    json: SceneJson,
    opts: StrippedSceneLoadOptions,
): Promise<void> {
    const sceneFileName = resolveSceneFileName(opts);
    const { imagePaths, soundPaths, fontPaths } = collectSceneAssetPaths(json, sceneFileName);
    const deferredImages = collectDeferredImagePaths(json, sceneFileName);
    const jg = (globalThis as { JulGame?: Record<string, unknown> }).JulGame;
    if (jg) {
        jg.memfsAssetBaseUrl = opts.memfsAssetBaseUrl;
        jg.emscriptenModule = emscriptenModule;
    }
    await syncAssetsToMemfs(emscriptenModule, imagePaths, soundPaths, fontPaths, opts.memfsAssetBaseUrl);
    flushPendingImageFetches();

    const existingEntityIds = new Set(scene.entities.map((e) => String((e as Entity).id)));
    const existingUiIds = new Set(scene.uiElements.map((u) => String((u as SceneTextBox).id)));

    for (const ent of json.Entities ?? []) {
        if (existingEntityIds.has(String(ent.id))) {
            continue;
        }
        const entity = buildEntityFromJson(ent, scene);
        if (entity) {
            scene.entities.push(entity);
        }
    }

    for (const ui of json.UIElements ?? []) {
        if (existingUiIds.has(String(ui.id ?? ""))) {
            continue;
        }
        const built = buildUiElementFromJson(ui);
        if (built) {
            scene.uiElements.push(built as never);
        }
    }

    applyCameraFromJson(scene, json, opts.canvasWidth, opts.canvasHeight);
    resolveUiElementParents(scene.uiElements, scene.entities);
    alignLoadedScreenTextBoxes(scene.uiElements);

    scene.colliders = [];
    scene.rigidbodies = [];
    for (const entity of scene.entities as Entity[]) {
        registerPhysics(scene, entity);
    }

    if (opts.loadScripts !== false) {
        instantiateScripts(scene.entities);
    }

    scheduleBackgroundAssetsToMemfs(emscriptenModule, deferredImages, opts.memfsAssetBaseUrl);
}

/** Fetch JSON then apply; on failure uses `MINIMAL_STRIPPED_SCENE`. */
export async function loadStrippedScene(
    scene: Scene,
    emscriptenModule: EmMod,
    opts: StrippedSceneLoadOptions,
): Promise<void> {
    let json: SceneJson = MINIMAL_STRIPPED_SCENE;
    console.info(`SceneBuilder: loading ${opts.sceneJsonUrl}`);
    try {
        const res = await fetch(opts.sceneJsonUrl);
        if (res.ok) {
            json = (await res.json()) as SceneJson;
        } else {
            console.warn(`SceneBuilder: fetch ${opts.sceneJsonUrl} status ${res.status}, using minimal scene`);
        }
    } catch (e) {
        console.warn("SceneBuilder: fetch failed, using minimal scene", e);
    }
    await applyStrippedSceneData(scene, emscriptenModule, json, opts);
    const sceneFile = opts.sceneJsonUrl.split("/").pop() ?? "";
    if (sceneFile) {
        scene.name = sceneFile.replace(/\.json$/i, "");
    }
}
