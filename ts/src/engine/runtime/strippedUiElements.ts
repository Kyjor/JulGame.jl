import type { JulGameSdlApi } from "../../platform/sdl-wasm/SDLBridge";
import { normalizeAssetPath } from "./projectConfig";

export type UiClickable = {
    onClick?: () => void;
    onHoverEnter?: () => void;
    onHoverExit?: () => void;
};

export type SceneUiImage = UiClickable & {
    type: "UIImage" | "ScreenButton";
    id: string | number;
    name: string;
    path: string;
    position: { x: number; y: number };
    size: { x: number; y: number };
    layer: number;
    isActive: boolean;
    isFlipped: boolean;
    color: [number, number, number, number];
    buttonUpSpritePath?: string;
    buttonDownSpritePath?: string;
    persistentBetweenScenes: boolean;
};

export type SceneCanvas = {
    type: "Canvas";
    id: string | number;
    name: string;
    isActive: boolean;
    layer: number;
    persistentBetweenScenes: boolean;
};

const imageTextures = new Map<string, number>();

export function parseJuliaUiColor(raw: unknown, alphaFallback = 255): [number, number, number, number] {
    if (raw && typeof raw === "object") {
        const o = raw as Record<string, number>;
        if ("r" in o && typeof o.r === "number") {
            return [o.r, o.g ?? 255, o.b ?? 255, o.a ?? alphaFallback];
        }
        return [
            o["1"] ?? 255,
            o["2"] ?? 255,
            o["3"] ?? 255,
            o["4"] ?? alphaFallback,
        ];
    }
    return [255, 255, 255, alphaFallback];
}

export function buildSceneUiImage(json: Record<string, unknown>, type: "UIImage" | "ScreenButton"): SceneUiImage {
    const path =
        type === "ScreenButton"
            ? String(json.buttonUpSpritePath ?? json.path ?? "")
            : String(json.path ?? "");
    return {
        type,
        id: (json.id as string | number) ?? 0,
        name: String(json.name ?? type),
        path: normalizeAssetPath(path),
        position: (json.position as { x: number; y: number }) ?? { x: 0, y: 0 },
        size: (json.size as { x: number; y: number }) ?? { x: 0, y: 0 },
        layer: typeof json.layer === "number" ? json.layer : 0,
        isActive: json.isActive !== false,
        isFlipped: !!json.isFlipped,
        color: parseJuliaUiColor(json.color, typeof json.alpha === "number" ? json.alpha : 255),
        buttonUpSpritePath:
            typeof json.buttonUpSpritePath === "string"
                ? normalizeAssetPath(json.buttonUpSpritePath)
                : undefined,
        buttonDownSpritePath:
            typeof json.buttonDownSpritePath === "string"
                ? normalizeAssetPath(json.buttonDownSpritePath)
                : undefined,
        persistentBetweenScenes: !!json.persistentBetweenScenes,
    };
}

export function buildSceneCanvas(json: Record<string, unknown>): SceneCanvas {
    return {
        type: "Canvas",
        id: (json.id as string | number) ?? 0,
        name: String(json.name ?? "Canvas"),
        isActive: json.isActive !== false,
        layer: typeof json.layer === "number" ? json.layer : 0,
        persistentBetweenScenes: !!json.persistentBetweenScenes,
    };
}

function settingsCanvasActive(uiElements: unknown[]): boolean {
    for (const ui of uiElements) {
        const c = ui as SceneCanvas;
        if (c.type === "Canvas" && c.name === "SettingsMenu_Canvas") {
            return c.isActive;
        }
    }
    return false;
}

function shouldDrawUi(ui: SceneUiImage, uiElements: unknown[]): boolean {
    if (!ui.isActive) {
        return false;
    }
    if (ui.name.startsWith("SettingsMenu_")) {
        return settingsCanvasActive(uiElements);
    }
    return true;
}

function loadUiTexture(api: JulGameSdlApi, imagePath: string): number | null {
    const cached = imageTextures.get(imagePath);
    if (cached) {
        return cached;
    }
    const fullPath = `/game/assets/images/${imagePath}`;
    const surface = api.glue_IMG_Load(fullPath);
    if (!surface) {
        console.warn(`strippedUiElements: failed to load ${fullPath}`);
        return null;
    }
    const createTex = api.glue_SDL_CreateTextureFromSurface as (surface: number) => number;
    const tex = createTex(surface);
    api.glue_SDL_FreeSurface(surface);
    if (!tex) {
        return null;
    }
    imageTextures.set(imagePath, tex);
    return tex;
}

export function clearUiImageTextureCache(api: JulGameSdlApi): void {
    const destroy = api.glue_SDL_DestroyTexture;
    if (typeof destroy === "function") {
        for (const tex of imageTextures.values()) {
            destroy(tex);
        }
    }
    imageTextures.clear();
}

export function drawUiImages(api: JulGameSdlApi, uiElements: unknown[]): void {
    const items: SceneUiImage[] = [];
    for (const ui of uiElements) {
        const el = ui as SceneUiImage;
        if (el.type !== "UIImage" && el.type !== "ScreenButton") {
            continue;
        }
        if (!shouldDrawUi(el, uiElements)) {
            continue;
        }
        items.push(el);
    }
    items.sort((a, b) => a.layer - b.layer);
    const renderCopy = api.glue_render_copy_ex;
    if (typeof renderCopy !== "function") {
        return;
    }
    api.glue_SDL_SetRenderDrawBlendMode_BLEND?.();
    for (const ui of items) {
        const tex = loadUiTexture(api, ui.path);
        if (!tex) {
            continue;
        }
        api.glue_SDL_SetTextureColorMod?.(tex, ui.color[0], ui.color[1], ui.color[2]);
        api.glue_SDL_SetTextureAlphaMod?.(tex, ui.color[3]);
        const x = Math.round(ui.position.x);
        const y = Math.round(ui.position.y);
        const w = Math.round(ui.size.x);
        const h = Math.round(ui.size.y);
        renderCopy(tex, 0, 0, 0, 0, 0, x, y, w, h, 0, 0, 0, ui.isFlipped ? 1 : 0);
    }
}

export function dispatchUiPointer(
    uiElements: unknown[],
    x: number,
    y: number,
    kind: "click" | "hover",
): boolean {
    const items: SceneUiImage[] = [];
    for (const ui of uiElements) {
        const el = ui as SceneUiImage;
        if (el.type !== "UIImage" && el.type !== "ScreenButton") {
            continue;
        }
        if (!shouldDrawUi(el, uiElements)) {
            continue;
        }
        items.push(el);
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
        if (kind === "click" && ui.onClick) {
            ui.onClick();
            return true;
        }
        if (kind === "hover" && ui.onHoverEnter) {
            ui.onHoverEnter();
            return true;
        }
        return true;
    }
    return false;
}
