import { Entity } from "../../../_generated/src/engine/Entity";
import { Component_destroy } from "../../../_generated/src/engine/Component/Sprite";
import { Component_unload_sound } from "../../../_generated/src/engine/Component/SoundSource";
import {
    get_entities_by_name,
    get_entity_by_id,
    get_entity_by_name,
    get_ui_element_by_id,
    get_ui_element_by_name,
} from "../../../_generated/src/engine/Scene";
import {
    createScript,
    hasScript,
    initializeScript,
    shutdownScript,
    updateScript,
} from "./scriptRegistry";

export type ScriptRefJson = {
    name: string;
    fields?: Record<string, unknown>;
};

function isScriptRef(value: unknown): value is ScriptRefJson {
    return (
        typeof value === "object" &&
        value !== null &&
        "name" in value &&
        typeof (value as ScriptRefJson).name === "string"
    );
}

function applyScriptFields(script: Record<string, unknown>, fields: Record<string, unknown> | undefined): void {
    if (!fields) {
        return;
    }
    for (const [key, value] of Object.entries(fields)) {
        if (value === null || value === undefined) {
            continue;
        }
        if (typeof value === "object" && Object.keys(value as object).length === 0) {
            continue;
        }
        try {
            script[key] = value;
        } catch {
            /* skip read-only / unknown fields */
        }
    }
}

/** Port of `SceneBuilder.add_scripts_to_entities` — JSON refs → live script instances. */
export function instantiateScripts(entities: Entity[]): void {
    for (const entity of entities) {
        const raw = entity.scripts as unknown[];
        if (!raw?.length) {
            continue;
        }
        const instances: unknown[] = [];
        for (const ref of raw) {
            if (!isScriptRef(ref)) {
                instances.push(ref);
                continue;
            }
            if (!hasScript(ref.name)) {
                console.warn(`scriptLoader: skipping unregistered script "${ref.name}" on ${entity.name}`);
                // Keep scene JSON slot so transpiled scripts[N] indices stay aligned with Julia.
                instances.push(null);
                continue;
            }
            try {
                const script = createScript(ref.name) as Record<string, unknown>;
                script.parent = entity;
                applyScriptFields(script, ref.fields);
                instances.push(script);
            } catch (e) {
                console.error(`scriptLoader: failed to create "${ref.name}" on ${entity.name}`, e);
                instances.push(null);
            }
        }
        entity.scripts = instances;
    }
}

export function initializeAllScripts(entities: Entity[]): void {
    for (const entity of entities) {
        if (!entity.isActive) {
            continue;
        }
        for (const script of entity.scripts) {
            if (script == null) {
                continue;
            }
            try {
                initializeScript(script);
            } catch (e) {
                console.error(`scriptLoader: initialize failed on ${entity.name}`, e);
            }
        }
    }
}

export function updateAllScripts(entities: Entity[], deltaTime: number): void {
    for (const entity of entities) {
        if (!entity.isActive) {
            continue;
        }
        for (const script of entity.scripts) {
            if (script == null) {
                continue;
            }
            try {
                updateScript(script, deltaTime);
            } catch (e) {
                console.error(`scriptLoader: update failed on ${entity.name}`, e);
            }
        }
    }
}

export function shutdownAllScripts(entities: Entity[]): void {
    for (const entity of entities) {
        for (const script of entity.scripts) {
            if (script == null) {
                continue;
            }
            try {
                shutdownScript(script);
            } catch {
                /* ignore */
            }
        }
    }
}

/** Minimal `JulGame.destroy_entity` for game scripts. */
/** Port of `JulGame.create_entity` — add a runtime-spawned entity to the active scene. */
export function createEntity(entity: Entity): Entity {
    const main = (globalThis as unknown as {
        MAIN: { scene: { entities: Entity[]; colliders: unknown[]; rigidbodies: unknown[] } };
    }).MAIN;
    const scene = main.scene;
    scene.entities.push(entity);
    if (entity.rigidbody) {
        scene.rigidbodies.push(entity.rigidbody);
    }
    if (entity.collider) {
        scene.colliders.push(entity.collider);
    }
    return entity;
}

export function destroyEntity(entity: Entity): void {
    const main = (globalThis as unknown as { MAIN: { scene: { entities: Entity[]; colliders: unknown[]; rigidbodies: unknown[] } } }).MAIN;
    const scene = main.scene;
    shutdownAllScripts([entity]);
    if (entity.sprite) {
        Component_destroy(entity.sprite as never);
    }
    const ss = entity.soundSource as Parameters<typeof Component_unload_sound>[0] | null;
    if (ss) {
        Component_unload_sound(ss);
    }
    entity.isActive = false;
    const ei = scene.entities.indexOf(entity);
    if (ei >= 0) {
        scene.entities.splice(ei, 1);
    }
    if (entity.collider) {
        const ci = scene.colliders.indexOf(entity.collider);
        if (ci >= 0) {
            scene.colliders.splice(ci, 1);
        }
    }
    if (entity.rigidbody) {
        const ri = scene.rigidbodies.indexOf(entity.rigidbody);
        if (ri >= 0) {
            scene.rigidbodies.splice(ri, 1);
        }
    }
}

export function wireSceneApi(jg: Record<string, unknown>): void {
    jg.EntityModule = {
        /** Julia `EntityModule.Entity(name)` — callable without `new`. */
        Entity: (name = "New entity") => new Entity(name),
    };
    jg.create_entity = (entity: Entity) => createEntity(entity);
    jg.SceneModule = {
        get_entity_by_id: (sceneOrId: unknown, id?: string) => get_entity_by_id(sceneOrId as never, id),
        get_entity_by_name: (sceneOrName: unknown, name?: string) =>
            get_entity_by_name(sceneOrName as never, name),
        get_entities_by_name: (sceneOrName: unknown, name?: string) =>
            get_entities_by_name(sceneOrName as never, name),
        get_ui_element_by_id: (sceneOrId: unknown, id?: string) =>
            get_ui_element_by_id(sceneOrId as never, id),
        get_ui_element_by_name: (sceneOrName: unknown, name?: string) =>
            get_ui_element_by_name(sceneOrName as never, name),
    };
    jg.destroy_entity = (_main: unknown, entity: Entity) => destroyEntity(entity);
}
