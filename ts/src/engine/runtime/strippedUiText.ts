import type { JulGameSdlApi } from "../../platform/sdl-wasm/SDLBridge";
import { normalizeAssetPath } from "./projectConfig";
import type { SceneTextBox } from "./SceneBuilder";

type SceneCamera = {
    position: { x: number; y: number; z: number };
    offset: { x: number; y: number };
};

type CachedTextTexture = {
    key: string;
    texture: number;
    w: number;
    h: number;
};

const openFonts = new Map<string, number>();
const textTextures = new Map<string, CachedTextTexture>();
let ttfMissingWarned = false;

function ttfAvailable(api: JulGameSdlApi): boolean {
    return (
        typeof api.glue_TTF_OpenFont === "function" &&
        typeof api.glue_TTF_RenderUTF8_Blended === "function"
    );
}

function textureCacheKey(ui: SceneTextBox): string {
    return `${ui.text}|${ui.fontSize}|${ui.fontPath}|${ui.color.join(",")}`;
}

export function clearUiFontCache(api: JulGameSdlApi): void {
    for (const font of openFonts.values()) {
        api.glue_TTF_CloseFont?.(font);
    }
    openFonts.clear();
    clearUiTextTextureCache(api);
}

export function clearUiTextTextureCache(api: JulGameSdlApi): void {
    const destroy = api.glue_SDL_DestroyTexture;
    if (typeof destroy === "function") {
        for (const entry of textTextures.values()) {
            if (entry.texture) {
                destroy(entry.texture);
            }
        }
    }
    textTextures.clear();
}

function loadFont(api: JulGameSdlApi, fontPath: string, fontSize: number): number | null {
    if (!ttfAvailable(api)) {
        if (!ttfMissingWarned) {
            console.warn(
                "strippedUiText: SDL_ttf glue missing from julgame.js — rebuild WASM: npm run build:wasm --prefix ../../JulGame.jl/ts",
            );
            ttfMissingWarned = true;
        }
        return null;
    }

    const cacheKey = `${fontPath}:${fontSize}`;
    const existing = openFonts.get(cacheKey);
    if (existing) {
        return existing;
    }

    const rel = normalizeAssetPath(fontPath);
    const font = api.glue_TTF_OpenFont!(`/game/assets/fonts/${rel}`, fontSize);
    if (!font) {
        console.warn(
            `strippedUiText: failed to load font "${rel}" size ${fontSize}: ${api.glue_SDL_GetError?.() ?? "unknown"}`,
        );
        return null;
    }
    openFonts.set(cacheKey, font);
    return font;
}

function getOrCreateTextTexture(
    api: JulGameSdlApi,
    ui: SceneTextBox,
    font: number,
): CachedTextTexture | null {
    const uiKey = String(ui.id);
    const contentKey = textureCacheKey(ui);
    const cached = textTextures.get(uiKey);
    if (cached && cached.key === contentKey) {
        return cached;
    }

    const renderBlended = api.glue_TTF_RenderUTF8_Blended!;
    const createTex = api.glue_SDL_CreateTextureFromSurface;
    const freeSurface = api.glue_SDL_FreeSurface;
    const destroyTexture = api.glue_SDL_DestroyTexture;

    const text = ui.text === "" ? " " : ui.text;
    const surface = renderBlended(font, text, ui.color[0], ui.color[1], ui.color[2], ui.color[3]);
    if (!surface) {
        return null;
    }

    const w = api.glue_surface_w(surface);
    const h = api.glue_surface_h(surface);
    const texture = createTex(0, surface);
    freeSurface(surface);
    if (!texture) {
        return null;
    }

    if (cached?.texture && typeof destroyTexture === "function") {
        destroyTexture(cached.texture);
    }

    const entry: CachedTextTexture = { key: contentKey, texture, w, h };
    textTextures.set(uiKey, entry);
    return entry;
}

/** Render scene UI TextBoxes with SDL_ttf (replaces white-rect placeholder). */
export function drawUiTextBoxes(
    api: JulGameSdlApi,
    uiElements: SceneTextBox[],
    cam: SceneCamera | null,
): void {
    const renderCopy = api.glue_render_copy_ex_f;
    const setColorMod = api.glue_SDL_SetTextureColorMod;
    const setAlphaMod = api.glue_SDL_SetTextureAlphaMod;
    if (!renderCopy || typeof api.glue_TTF_RenderUTF8_Blended !== "function" || !ttfAvailable(api)) {
        return;
    }

    api.glue_SDL_SetRenderDrawBlendMode_BLEND?.();

    for (const ui of uiElements) {
        if (!ui.isActive || !ui.text || !ui.fontPath) {
            continue;
        }

        const font = loadFont(api, ui.fontPath, ui.fontSize);
        if (!font) {
            continue;
        }

        const tex = getOrCreateTextTexture(api, ui, font);
        if (!tex) {
            continue;
        }

        setColorMod?.(tex.texture, 255, 255, 255);
        setAlphaMod?.(tex.texture, ui.color[3]);

        let x = ui.position.x;
        let y = ui.position.y;
        if (ui.isCenteredX && cam) {
            x -= tex.w / 2;
        }
        if (ui.isCenteredY && cam) {
            y -= tex.h / 2;
        }

        renderCopy(tex.texture, 0, 0, 0, 0, 0, x, y, tex.w, tex.h, 0, 0, 0, 0);
    }
}
