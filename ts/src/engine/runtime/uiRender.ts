import type { JulGameSdlApi } from "../../platform/sdl-wasm/SDLBridge";
import { buildInactiveCanvasHiddenSet } from "../../../_generated/src/engine/UI/Canvas";
import type { TextBoxElement } from "../../../_generated/src/engine/UI/TextBox";
import { UI_load_font, UI_render_TextBox } from "../../../_generated/src/engine/UI/TextBox";
import type { ScreenButtonElement } from "../../../_generated/src/engine/UI/ScreenButton";
import { UI_initialize_ScreenButton, UI_render_ScreenButton } from "../../../_generated/src/engine/UI/ScreenButton";
import type { UiImageElement } from "../../../_generated/src/engine/UI/UIImage";
import { UI_initialize_UIImage, UI_render_UIImage } from "../../../_generated/src/engine/UI/UIImage";
import type { JulGameUiElement } from "../../../_generated/src/engine/UI/uiTypes";
import {
    beginUiDrawProfileFrame,
    finishUiElementDraw,
    recordUiFramePhase,
    timeUiDrawStep,
    type UiProfiledElement,
} from "./uiDrawProfile";

type UiRenderable = JulGameUiElement & { type: string };

function isRenderableUi(el: unknown): el is UiRenderable {
    if (!el || typeof el !== "object") {
        return false;
    }
    const t = (el as UiRenderable).type;
    return t === "UIImage" || t === "ScreenButton" || t === "TextBox";
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
        settingsMenuDrawn: 0,
    };
    const items: UiRenderable[] = [];
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

export function dispatchUiPointer(
    uiElements: unknown[],
    x: number,
    y: number,
    kind: "click" | "hover",
): boolean {
    const items: UiRenderable[] = [];
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
    for (const ui of items) {
        const left = ui.position.x;
        const top = ui.position.y;
        const right = left + ui.size.x;
        const bottom = top + ui.size.y;
        if (x < left || x > right || y < top || y > bottom) {
            continue;
        }
        if (kind === "click") {
            for (const fn of ui.clickEvents) {
                fn();
            }
            return true;
        }
        if (kind === "hover") {
            for (const fn of ui.hoverEnterEvents) {
                fn();
            }
            return true;
        }
        return true;
    }
    return false;
}
