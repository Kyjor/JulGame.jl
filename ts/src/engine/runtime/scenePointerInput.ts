import type { UiHoverTarget } from "../../../_generated/src/engine/UI/uiTypes";
import {
    dispatchUiMouseUpClicks,
    hitTestUiTopmost,
    pointInUiRect,
    prepareUiHitTestItems,
    shouldParticipateInUiHitTest,
} from "./uiRender";

type SceneEntity = {
    isActive?: boolean;
    ignoreInputEvents?: boolean;
    isHovered?: boolean;
    clickEvents?: Array<() => void>;
    hoverEnterEvents?: Array<() => void>;
    hoverExitEvents?: Array<() => void>;
    forceClickCheck?: boolean;
    sprite?: {
        layer?: number;
        lastRenderedScreenPosition?: { x: number; y: number } | null;
        lastRenderedScreenSize?: { x: number; y: number } | null;
        interactionScale?: number;
    } | null;
};

export type SceneShape = {
    uiElements?: unknown[];
    entities?: SceneEntity[];
};

function entityLayer(entity: SceneEntity): number {
    return entity.sprite?.layer ?? 0;
}

function entityHitRect(entity: SceneEntity): { x: number; y: number; w: number; h: number } | null {
    const sprite = entity.sprite;
    if (!sprite?.lastRenderedScreenPosition || !sprite.lastRenderedScreenSize) {
        return null;
    }
    const interactionScale = sprite.interactionScale ?? 1;
    const basePos = sprite.lastRenderedScreenPosition;
    const baseSize = sprite.lastRenderedScreenSize;
    const w = baseSize.x * interactionScale;
    const h = baseSize.y * interactionScale;
    const ox = (baseSize.x * (1 - interactionScale)) / 2;
    const oy = (baseSize.y * (1 - interactionScale)) / 2;
    return { x: basePos.x + ox, y: basePos.y + oy, w, h };
}

function pointInEntity(entity: SceneEntity, x: number, y: number): boolean {
    const rect = entityHitRect(entity);
    if (!rect) {
        return false;
    }
    return x >= rect.x && x <= rect.x + rect.w && y >= rect.y && y <= rect.y + rect.h;
}

function collectActiveEntities(entities: SceneEntity[]): SceneEntity[] {
    return entities.filter(
        (e) => e.isActive !== false && !e.ignoreInputEvents && e.sprite != null,
    );
}

function isSceneEntity(ref: unknown): ref is SceneEntity {
    if (!ref || typeof ref !== "object") {
        return false;
    }
    const r = ref as Record<string, unknown>;
    if (typeof r.type === "string") {
        return false;
    }
    return r.sprite != null;
}

/** Topmost press target at pointer — UI overlays and sprites merged by layer (Julia Input). */
export function hitTestScenePressTarget(scene: SceneShape, x: number, y: number): unknown | null {
    let best: { ref: unknown; layer: number } | null = null;

    const uiElements = scene.uiElements ?? [];
    if (uiElements.length > 0) {
        const uiHit = hitTestUiTopmost(uiElements, x, y);
        if (uiHit) {
            best = { ref: uiHit, layer: uiHit.layer };
        }
    }

    for (const entity of collectActiveEntities(scene.entities ?? [])) {
        if (!pointInEntity(entity, x, y)) {
            continue;
        }
        const layer = entityLayer(entity);
        if (!best || layer > best.layer) {
            best = { ref: entity, layer };
        }
    }

    return best?.ref ?? null;
}

function dispatchEntityClick(entity: SceneEntity): void {
    for (const fn of entity.clickEvents ?? []) {
        fn();
    }
}

/** Julia mouse-up: walk UI + entities top-to-bottom; block lower targets; honor forceClickCheck. */
export function dispatchSceneMouseUpClicks(scene: SceneShape, x: number, y: number, pressTarget: unknown | null): void {
    // Entity sprites (map nodes, etc.) — Julia Input fires clickEvents on mouseup after mousedown on same element.
    if (isSceneEntity(pressTarget)) {
        const entity = pressTarget;
        const hasHandlers = (entity.clickEvents?.length ?? 0) > 0;
        if (hasHandlers && (pointInEntity(entity, x, y) || entity.isHovered)) {
            dispatchEntityClick(entity);
            return;
        }
    }

    type Entry = { ref: unknown; layer: number; forceClickCheck: boolean; clickEvents: Array<() => void> };
    const entries: Entry[] = [];

    for (const ui of prepareUiHitTestItems(scene.uiElements ?? [])) {
        if (!shouldParticipateInUiHitTest(ui)) {
            continue;
        }
        entries.push({
            ref: ui,
            layer: ui.layer,
            forceClickCheck: !!(ui as { forceClickCheck?: boolean }).forceClickCheck,
            clickEvents: ui.clickEvents,
        });
    }

    for (const entity of collectActiveEntities(scene.entities ?? [])) {
        entries.push({
            ref: entity,
            layer: entityLayer(entity),
            forceClickCheck: !!entity.forceClickCheck,
            clickEvents: entity.clickEvents ?? [],
        });
    }

    entries.sort((a, b) => b.layer - a.layer);

    let clickedAnElementAlready = false;
    for (const entry of entries) {
        const inside = isSceneEntity(entry.ref)
            ? pointInEntity(entry.ref, x, y)
            : pointInUiRect(entry.ref as UiHoverTarget, x, y);
        if (!inside) {
            continue;
        }

        const canClick =
            (!clickedAnElementAlready || entry.forceClickCheck) &&
            pressTarget === entry.ref &&
            entry.clickEvents.length > 0;

        if (canClick) {
            if (isSceneEntity(entry.ref)) {
                dispatchEntityClick(entry.ref);
            } else {
                for (const fn of entry.clickEvents) {
                    fn();
                }
            }
        }
        clickedAnElementAlready = true;
    }

    // Fallback: UI-only path when no entries (keeps prior UI-only behavior).
    if (entries.length === 0 && (scene.uiElements?.length ?? 0) > 0) {
        dispatchUiMouseUpClicks(scene.uiElements ?? [], x, y, pressTarget as UiHoverTarget | null);
    }
}

/** Set `entity.isHovered` on the topmost sprite under the pointer (UI overlays block). */
export function updateSceneEntityHover(scene: SceneShape, x: number, y: number): void {
    const target = hitTestScenePressTarget(scene, x, y);
    const hoverEntity = isSceneEntity(target) ? target : null;

    for (const entity of scene.entities ?? []) {
        if (!entity.sprite || entity.ignoreInputEvents) {
            continue;
        }
        const shouldHover = entity === hoverEntity;
        if (shouldHover && !entity.isHovered) {
            entity.isHovered = true;
            for (const fn of entity.hoverEnterEvents ?? []) {
                fn();
            }
        } else if (!shouldHover && entity.isHovered) {
            entity.isHovered = false;
            for (const fn of entity.hoverExitEvents ?? []) {
                fn();
            }
        }
    }
}
