import { Entity } from "../../../_generated/src/engine/Entity";
import { Transform, Component_duplicate as duplicateTransform } from "../../../_generated/src/engine/Component/Transform";
import {
    Component_duplicate as duplicateSprite,
} from "../../../_generated/src/engine/Component/Sprite";
import { InternalCollider } from "../../../_generated/src/engine/Component/Collider";
import { InternalSoundSource } from "../../../_generated/src/engine/Component/SoundSource";
import { InternalRigidbody } from "../../../_generated/src/engine/Component/Rigidbody";

type SceneShape = {
    entities: Entity[];
    colliders: InternalCollider[];
};

/** Mirrors `JulGame.duplicate` in `src/engine/Entity.jl` for web runtime. */
export function duplicateEntity(source: Entity, id?: string): Entity {
    const jg = (globalThis as { JulGame?: { generate_uuid?: () => string } }).JulGame;
    const newId =
        id ??
        jg?.generate_uuid?.() ??
        (typeof crypto !== "undefined" && "randomUUID" in crypto
            ? crypto.randomUUID()
            : `dup-${Math.random().toString(36).slice(2, 11)}`);

    const transform = source.transform
        ? duplicateTransform(source.transform, null)
        : new Transform();
    const newEntity = new Entity(source.name, newId, transform);
    newEntity.transform.parent = newEntity;
    newEntity.isActive = source.isActive;
    newEntity.persistentBetweenScenes = source.persistentBetweenScenes;

    if (source.collider) {
        const c = source.collider;
        newEntity.collider = new InternalCollider(
            newEntity,
            { x: c.size.x, y: c.size.y },
            { x: c.offset.x, y: c.offset.y },
            c.tag,
            c.isTrigger,
            c.isPlatformerCollider,
            c.enabled,
        );
    }
    if (source.sprite) {
        newEntity.sprite = duplicateSprite(source.sprite, newEntity);
    }
    if (source.soundSource) {
        const ss = source.soundSource;
        newEntity.soundSource = new InternalSoundSource(
            newEntity,
            ss.path,
            ss.channel,
            ss.volume,
            ss.isMusic,
            ss.playOnStart,
        );
    }
    if (source.rigidbody) {
        newEntity.rigidbody = new InternalRigidbody(
            newEntity,
            source.rigidbody.mass,
            source.rigidbody.useGravity,
        );
    }
    if (source.softwareRenderer3d) {
        newEntity.softwareRenderer3d = source.softwareRenderer3d;
    }

    const scene = (globalThis as { MAIN?: { scene?: SceneShape } }).MAIN?.scene;
    if (scene) {
        scene.entities.push(newEntity);
        if (newEntity.collider) {
            scene.colliders.push(newEntity.collider);
        }
    }
    return newEntity;
}
