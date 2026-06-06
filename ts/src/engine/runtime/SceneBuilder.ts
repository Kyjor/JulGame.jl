import { Camera } from "../../../_generated/src/engine/Camera/Camera";
import { Entity, JulGame_add_sprite } from "../../../_generated/src/engine/Entity";
import { Transform } from "../../../_generated/src/engine/Component/Transform";
import type { Scene } from "../../../_generated/src/engine/Scene";
import { attachDefaultCamera } from "./julGameBootstrap";

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
    /** HTTP base whose `/assets/images/...` are fetched into MEMFS under `/game/assets/images/`. */
    memfsAssetBaseUrl: string;
    canvasWidth: number;
    canvasHeight: number;
    /** Cap entities deserialized (large editor scenes). */
    maxEntities?: number;
};

type EmMod = { FS?: { mkdirTree: (p: string) => void; writeFile: (p: string, d: Uint8Array) => void } };

export type SceneJson = {
    Entities?: EntityJson[];
    Camera?: {
        size: { x: number; y: number };
        position: { x: number; y: number };
        offset?: { x: number; y: number };
        backgroundColor?: { r: number; g: number; b: number; a: number };
        zoom?: number;
    };
};

type EntityJson = {
    id: string | number;
    name: string;
    isActive?: boolean;
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
};

async function syncSpriteAssetsToMemfs(
    emscriptenModule: EmMod,
    imagePaths: Set<string>,
    memfsAssetBaseUrl: string,
): Promise<void> {
    const fs = emscriptenModule.FS;
    if (!fs) {
        console.warn("SceneBuilder: Emscripten FS not available; IMG_Load may fail");
        return;
    }
    fs.mkdirTree("/game/assets/images");

    for (const rel of imagePaths) {
        const memPath = `/game/assets/images/${rel}`;
        const url = `${memfsAssetBaseUrl.replace(/\/$/, "")}/assets/images/${rel}`;
        try {
            const res = await fetch(url);
            if (!res.ok) {
                throw new Error(String(res.status));
            }
            const buf = new Uint8Array(await res.arrayBuffer());
            fs.writeFile(memPath, buf);
        } catch {
            fs.writeFile(memPath, PNG_1X1);
            console.warn(`SceneBuilder: using 1×1 placeholder for missing asset: ${url}`);
        }
    }
}

/**
 * Apply already-parsed scene JSON (fetch separately or use `MINIMAL_STRIPPED_SCENE`).
 */
export async function applyStrippedSceneData(
    scene: Scene,
    emscriptenModule: EmMod,
    json: SceneJson,
    opts: StrippedSceneLoadOptions,
): Promise<void> {
    const max = opts.maxEntities ?? 128;
    const list = (json.Entities ?? []).slice(0, max);

    const imagePaths = new Set<string>();
    for (const ent of list) {
        for (const c of ent.components ?? []) {
            if (c.type === "Sprite" && typeof c.imagePath === "string") {
                imagePaths.add(c.imagePath);
            }
        }
    }
    await syncSpriteAssetsToMemfs(emscriptenModule, imagePaths, opts.memfsAssetBaseUrl);

    scene.entities = [];
    scene.uiElements = [];
    scene.colliders = [];
    scene.rigidbodies = [];
    scene.batchedLayers = {};

    for (const ent of list) {
        let transformComp: ComponentJson | null = null;
        let spriteComp: ComponentJson | null = null;
        for (const c of ent.components ?? []) {
            if (c.type === "Transform") {
                transformComp = c;
            } else if (c.type === "Sprite") {
                spriteComp = c;
            }
        }
        if (!transformComp) {
            console.debug(`SceneBuilder: skip entity ${ent.name} — no Transform`);
            continue;
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
        const entity = new Entity(ent.name, String(ent.id), tr, ent.scripts ?? []);
        entity.isActive = ent.isActive !== false;

        if (spriteComp && spriteComp.imagePath) {
            const cr = spriteComp.crop;
            const hasCrop =
                cr &&
                typeof cr.x === "number" &&
                typeof cr.y === "number" &&
                typeof cr.z === "number" &&
                typeof cr.t === "number" &&
                !(cr.x === 0 && cr.y === 0 && cr.z === 0 && cr.t === 0);
            const crop = hasCrop ? { x: cr!.x!, y: cr!.y!, z: cr!.z!, t: cr!.t! } : null;
            JulGame_add_sprite(entity, false, {
                imagePath: spriteComp.imagePath,
                crop,
                isFlipped: !!spriteComp.isFlipped,
                color: [255, 255, 255, 255],
                pixelsPerUnit:
                    typeof spriteComp.pixelsPerUnit === "number"
                        ? spriteComp.pixelsPerUnit
                        : ((globalThis as { JulGame?: { PIXELS_PER_UNIT?: number } }).JulGame
                              ?.PIXELS_PER_UNIT ?? 64),
                position: { x: 0, y: 0 },
                rotation: 0,
                layer: 0,
                center: { x: 0.5, y: 0.5 },
                anchor: "center",
                offset: { x: 0, y: 0 },
                isStatic: false,
            });
        }

        scene.entities.push(entity);
    }

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
        attachDefaultCamera(scene, opts.canvasWidth, opts.canvasHeight);
    }
}

/** Fetch JSON then apply; on failure uses `MINIMAL_STRIPPED_SCENE`. */
export async function loadStrippedScene(
    scene: Scene,
    emscriptenModule: EmMod,
    opts: StrippedSceneLoadOptions,
): Promise<void> {
    let json: SceneJson = MINIMAL_STRIPPED_SCENE;
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
}
