import { UI_load_font, type TextBoxElement } from "../../../_generated/src/engine/UI/TextBox";
import { UI_initialize_UIImage, type UiImageElement } from "../../../_generated/src/engine/UI/UIImage";
import type { JulGameUiElement } from "../../../_generated/src/engine/UI/uiTypes";
import type { JulGameSdlApi } from "../../platform/sdl-wasm/SDLBridge";

function generateUiId(): string {
    const jg = (globalThis as { JulGame?: { generate_uuid?: () => string } }).JulGame;
    return (
        jg?.generate_uuid?.() ??
        (typeof crypto !== "undefined" && "randomUUID" in crypto
            ? crypto.randomUUID()
            : `ui-${Math.random().toString(36).slice(2, 11)}`)
    );
}

function cloneUiElement(source: JulGameUiElement, id?: string): JulGameUiElement {
    const clone = (
        typeof structuredClone === "function"
            ? structuredClone(source)
            : (JSON.parse(JSON.stringify(source)) as JulGameUiElement)
    );
    clone.id = id ?? generateUiId();
    clone.clickEvents = [];
    clone.hoverEnterEvents = [];
    clone.hoverExitEvents = [];
    if (clone.type === "TextBox") {
        const tb = clone as TextBoxElement;
        tb.font = null;
        tb.textTexture = null;
    } else if (clone.type === "UIImage") {
        (clone as UiImageElement).texture = null;
    }
    return clone;
}

function initializeDuplicatedUi(api: JulGameSdlApi, el: JulGameUiElement): void {
    if (el.type === "UIImage") {
        UI_initialize_UIImage(api, el as UiImageElement);
    } else if (el.type === "TextBox") {
        UI_load_font(api, el as TextBoxElement);
    }
}

/** Mirrors `JulGame.UI.duplicate` for TextBox / UIImage prefabs on web. */
export function duplicateUiElement(source: unknown, id?: string): unknown {
    if (source == null || typeof source !== "object") {
        throw new Error("UI.duplicate: invalid source element");
    }
    const clone = cloneUiElement(source as JulGameUiElement, id);
    const api = (globalThis as { JulGameSdl?: JulGameSdlApi }).JulGameSdl;
    if (api) {
        initializeDuplicatedUi(api, clone);
    }
    const scene = (globalThis as { MAIN?: { scene?: { uiElements?: unknown[] } } }).MAIN?.scene;
    scene?.uiElements?.push(clone);
    return clone;
}
