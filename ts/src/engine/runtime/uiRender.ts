import type { JulGameSdlApi } from "../../platform/sdl-wasm/SDLBridge";
import { buildInactiveCanvasHiddenSet } from "../../../_generated/src/engine/UI/Canvas";
import type { TextBoxElement } from "../../../_generated/src/engine/UI/TextBox";
import { UI_load_font, UI_render_TextBox } from "../../../_generated/src/engine/UI/TextBox";
import type { ScreenButtonElement } from "../../../_generated/src/engine/UI/ScreenButton";
import { UI_initialize_ScreenButton, UI_render_ScreenButton } from "../../../_generated/src/engine/UI/ScreenButton";
import type { UiImageElement } from "../../../_generated/src/engine/UI/UIImage";
import { UI_initialize_UIImage, UI_render_UIImage } from "../../../_generated/src/engine/UI/UIImage";
import type { RectangleElement } from "../../../_generated/src/engine/UI/Rectangle";
import { UI_render_Rectangle } from "../../../_generated/src/engine/UI/Rectangle";
import type { JulGameUiElement } from "../../../_generated/src/engine/UI/uiTypes";
import { UI_align_to_anchor } from "../../../_generated/src/engine/UI/UIElement";
import {
    beginUiDrawProfileFrame,
    finishUiElementDraw,
    recordUiFramePhase,
    timeUiDrawStep,
    type UiProfiledElement,
} from "./uiDrawProfile";

export type UiHoverTarget = JulGameUiElement & { type: string };

function isRenderableUi(el: unknown): el is UiHoverTarget {
    if (!el || typeof el !== "object") {
        return false;
    }
    const t = (el as UiHoverTarget).type;
    return t === "UIImage" || t === "ScreenButton" || t === "TextBox" || t === "Rectangle";
}

/** Julia MainLoop UI pass: sort by layer, respect canvas visibility, dispatch UI.render. */
export function initializeSceneUi(api: JulGameSdlApi, uiElements: unknown[]): void {
    for (const raw of uiElements) {
        if (!isRenderableUi(raw)) {
            continue;
        }
        switch (raw.type) {
            case "UIImage":
                UI_initialize_UIImage(api, raw as UiImageElement);
                break;
            case "ScreenButton":
                UI_initialize_ScreenButton(api, raw as ScreenButtonElement);
                break;
            case "TextBox":
                UI_load_font(api, raw as TextBoxElement);
                break;
        }
    }
}

export type UiDrawStats = {
    drawn: number;
    skippedHidden: number;
    skippedInactive: number;
    images: number;
    buttons: number;
    textBoxes: number;
    rectangles: number;
    settingsMenuDrawn: number;
};

export function renderSceneUi(api: JulGameSdlApi, uiElements: unknown[]): UiDrawStats {
    beginUiDrawProfileFrame();
    const stats: UiDrawStats = {
        drawn: 0,
        skippedHidden: 0,
        skippedInactive: 0,
        images: 0,
        buttons: 0,
        textBoxes: 0,
        rectangles: 0,
        settingsMenuDrawn: 0,
    };
    const items: UiHoverTarget[] = [];
    const collectT0 = performance.now();
    const hiddenByCanvas = buildInactiveCanvasHiddenSet(uiElements);
    for (const raw of uiElements) {
        if (!isRenderableUi(raw)) {
            continue;
        }
        if (raw.isActive === false) {
            stats.skippedInactive++;
            continue;
        }
        if (hiddenByCanvas.has(raw)) {
            stats.skippedHidden++;
            continue;
        }
        items.push(raw);
    }
    recordUiFramePhase("collect", performance.now() - collectT0);
    const sortT0 = performance.now();
    items.sort((a, b) => a.layer - b.layer);
    recordUiFramePhase("sort", performance.now() - sortT0);
    const blendT0 = performance.now();
    api.glue_SDL_SetRenderDrawBlendMode_BLEND?.();
    recordUiFramePhase("blend", performance.now() - blendT0);
    const drawT0 = performance.now();
    for (const el of items) {
        const elT0 = performance.now();
        timeUiDrawStep(`draw.${el.type}`, () => {
            switch (el.type) {
                case "UIImage":
                    UI_render_UIImage(api, el as UiImageElement);
                    stats.images++;
                    break;
                case "ScreenButton":
                    UI_render_ScreenButton(api, el as ScreenButtonElement);
                    stats.buttons++;
                    break;
                case "TextBox":
                    UI_render_TextBox(api, el as TextBoxElement);
                    stats.textBoxes++;
                    break;
                case "Rectangle":
                    UI_render_Rectangle(api, el as RectangleElement);
                    stats.rectangles++;
                    break;
            }
        });
        finishUiElementDraw(el as UiProfiledElement, el.name, el.type, performance.now() - elT0);
        stats.drawn++;
        if (el.name.startsWith("SettingsMenu_")) {
            stats.settingsMenuDrawn++;
        }
    }
    recordUiFramePhase("draw", performance.now() - drawT0);
    return stats;
}

/** Map canvas pixel coords to SDL logical UI space (matches Julia Input mouse scaling). */
export function canvasPixelsToLogicalUiSpace(
    canvasWidth: number,
    canvasHeight: number,
    x: number,
    y: number,
): { x: number; y: number } {
    const root = globalThis as {
        MAIN?: { scene?: { camera?: { size?: { x: number; y: number } } } };
    };
    const cam = root.MAIN?.scene?.camera?.size;
    const logicalW = cam?.x && cam.x > 0 ? cam.x : canvasWidth;
    const logicalH = cam?.y && cam.y > 0 ? cam.y : canvasHeight;
    if (logicalW === canvasWidth && logicalH === canvasHeight) {
        return { x, y };
    }
    const scale = Math.min(canvasWidth / logicalW, canvasHeight / logicalH);
    const contentW = logicalW * scale;
    const contentH = logicalH * scale;
    const barX = (canvasWidth - contentW) / 2;
    const barY = (canvasHeight - contentH) / 2;
    return {
        x: Math.max(0, Math.min(logicalW, (x - barX) / scale)),
        y: Math.max(0, Math.min(logicalH, (y - barY) / scale)),
    };
}

function collectHitTestableUi(uiElements: unknown[]): UiHoverTarget[] {
    const items: UiHoverTarget[] = [];
    const hiddenByCanvas = buildInactiveCanvasHiddenSet(uiElements);
    for (const raw of uiElements) {
        if (!isRenderableUi(raw)) {
            continue;
        }
        if (raw.isActive === false || hiddenByCanvas.has(raw)) {
            continue;
        }
        items.push(raw);
    }
    items.sort((a, b) => b.layer - a.layer);
    return items;
}

function pointInUiRect(ui: UiHoverTarget, x: number, y: number): boolean {
    const left = ui.position.x;
    const top = ui.position.y;
    const right = left + ui.size.x;
    const bottom = top + ui.size.y;
    return x >= left && x <= right && y >= top && y <= bottom;
}

function isUiInteractiveTarget(ui: UiHoverTarget): boolean {
    return ui.clickEvents.length > 0 || ui.hoverEnterEvents.length > 0 || ui.hoverExitEvents.length > 0;
}

/** Topmost UI element at pointer — includes non-interactive panels/overlays that block clicks below. */
export function hitTestUiTopmost(uiElements: unknown[], x: number, y: number): UiHoverTarget | null {
    return hitTestUiAt(prepareUiHitTestItems(uiElements), x, y, false);
}

/** Topmost interactive element, falling through labels/panels without handlers. */
export function hitTestUiInteractive(uiElements: unknown[], x: number, y: number): UiHoverTarget | null {
    const items = prepareUiHitTestItems(uiElements);
    for (const ui of items) {
        if (!pointInUiRect(ui, x, y)) {
            continue;
        }
        if (isUiInteractiveTarget(ui)) {
            return ui;
        }
    }
    return null;
}

function shouldParticipateInUiHitTest(ui: UiHoverTarget): boolean {
    // Decorative labels (e.g. immediate_button text) must not steal clicks from the button below.
    if (ui.type === "TextBox" && !isUiInteractiveTarget(ui)) {
        return false;
    }
    return true;
}

function hitTestUiAt(items: UiHoverTarget[], x: number, y: number, interactiveOnly = false): UiHoverTarget | null {
    for (const ui of items) {
        if (!shouldParticipateInUiHitTest(ui)) {
            continue;
        }
        if (interactiveOnly && !isUiInteractiveTarget(ui)) {
            continue;
        }
        if (pointInUiRect(ui, x, y)) {
            return ui;
        }
    }
    return null;
}

function prepareUiHitTestItems(uiElements: unknown[]): UiHoverTarget[] {
    const items = collectHitTestableUi(uiElements);
    const alignOrder = [...items].sort((a, b) => a.layer - b.layer);
    for (const ui of alignOrder) {
        if (!ui.isWorldEntity) {
            UI_align_to_anchor(ui);
        }
    }
    return items;
}

export function hitTestUiPointer(uiElements: unknown[], x: number, y: number): UiHoverTarget | null {
    return hitTestUiInteractive(uiElements, x, y);
}

/** Julia mouse-up pass: walk top-to-bottom; block lower UI; honor `forceClickCheck`. */
export function dispatchUiMouseUpClicks(
    uiElements: unknown[],
    x: number,
    y: number,
    pressTarget: UiHoverTarget | null,
): boolean {
    const items = prepareUiHitTestItems(uiElements);
    let clickedAnElementAlready = false;
    let consumed = false;

    for (const ui of items) {
        if (!shouldParticipateInUiHitTest(ui) || !pointInUiRect(ui, x, y)) {
            continue;
        }
        consumed = true;

        const forceClickCheck = !!(ui as { forceClickCheck?: boolean }).forceClickCheck;
        const clickedDownHere = pressTarget === ui;
        const canClick =
            (!clickedAnElementAlready || forceClickCheck) &&
            clickedDownHere &&
            ui.clickEvents.length > 0;

        if (canClick) {
            dispatchUiClick(ui);
        }
        clickedAnElementAlready = true;
    }
    return consumed;
}

/** Whether any UI (including non-interactive overlays) covers this point. */
export function isUiPointerBlocked(uiElements: unknown[], x: number, y: number): boolean {
    return hitTestUiTopmost(uiElements, x, y) !== null;
}

/** Fire registered click handlers (Julia fires these on mouseup after mousedown on the same element). */
export function dispatchUiClick(hit: UiHoverTarget): void {
    for (const fn of hit.clickEvents) {
        fn();
    }
}

export function dispatchUiPointer(
    uiElements: unknown[],
    x: number,
    y: number,
    kind: "click" | "hover",
): boolean {
    const hit = hitTestUiPointer(uiElements, x, y);
    if (!hit) {
        return false;
    }
    if (kind === "click") {
        dispatchUiClick(hit);
        return true;
    }
    for (const fn of hit.hoverEnterEvents) {
        fn();
    }
    return true;
}

/** Fire hover enter/exit when the topmost interactive target changes. */
export function updateUiPointerHover(
    uiElements: unknown[],
    x: number,
    y: number,
    lastHovered: UiHoverTarget | null,
): UiHoverTarget | null {
    const hit = hitTestUiInteractive(uiElements, x, y);
    if (hit === lastHovered) {
        return lastHovered;
    }
    if (lastHovered) {
        (lastHovered as UiHoverTarget & { isHovered?: boolean }).isHovered = false;
        for (const fn of lastHovered.hoverExitEvents) {
            fn();
        }
    }
    if (hit) {
        (hit as UiHoverTarget & { isHovered?: boolean }).isHovered = true;
        for (const fn of hit.hoverEnterEvents) {
            fn();
        }
    }
    return hit;
}
