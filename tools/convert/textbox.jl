# TextBox.jl → TextBox.ts (screen-space render path from Julia UI.render).

function is_textbox_source(path_jl::AbstractString)::Bool
    return endswith(replace(normpath(String(path_jl)), '\\' => '/'), "/src/engine/UI/TextBox.jl")
end

function postprocess_textbox_ts(_data::AbstractString)::String
    return """
import type { JulGameSdlApi } from "../../../../src/platform/sdl-wasm/SDLBridge";
import { normalizeAssetPath } from "../../../../src/engine/runtime/projectConfig";
import type { UiProfiledElement } from "../../../../src/engine/runtime/uiDrawProfile";
import { UI_align_to_anchor } from "./UIElement";
import { parseJuliaUiColor, type JulGameUiElement } from "./uiTypes";

export type TextBoxElement = JulGameUiElement & {
    type: "TextBox";
    text: string;
    fontPath: string;
    fontSize: number;
    font: number | null;
    textTexture: number | null;
    isCenteredX: boolean;
    isCenteredY: boolean;
    isDynamic: boolean;
    maxLineWidth: number;
    wrapWords: boolean;
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

function textureCacheKey(ui: TextBoxElement): string {
    return ui.text + "|" + ui.fontSize + "|" + ui.fontPath + "|" + ui.color.join(",");
}

export function hydrateTextBoxFromJson(json: Record<string, unknown>): TextBoxElement {
    const color = parseJuliaUiColor(json.color, typeof json.alpha === "number" ? json.alpha : 255);
    return {
        type: "TextBox",
        id: (json.id as string | number) ?? 0,
        name: String(json.name ?? "TextBox"),
        text: String(json.text ?? ""),
        fontSize: typeof json.fontSize === "number" ? json.fontSize : 24,
        fontPath: json.fontPath ? normalizeAssetPath(String(json.fontPath)) : "",
        position: (json.position as { x: number; y: number }) ?? { x: 0, y: 0 },
        size: (json.size as { x: number; y: number }) ?? { x: 100, y: 24 },
        originalSize: (json.size as { x: number; y: number }) ?? { x: 100, y: 24 },
        isActive: json.isActive !== false,
        color,
        persistentBetweenScenes: !!json.persistentBetweenScenes,
        isWorldEntity: json.isWorldEntity === true,
        isCenteredX: !!json.isCenteredX,
        isCenteredY: !!json.isCenteredY,
        anchor: { current_state: String(json.anchor ?? "none") },
        anchorOffset: (json.anchorOffset as { x: number; y: number }) ?? { x: 0, y: 0 },
        parent: json.parent ?? null,
        clickEvents: [],
        hoverEnterEvents: [],
        hoverExitEvents: [],
        layer: typeof json.layer === "number" ? json.layer : 0,
        font: null,
        textTexture: null,
        isDynamic: !!json.isDynamic,
        maxLineWidth: typeof json.maxLineWidth === "number" ? json.maxLineWidth : 0,
        wrapWords: json.wrapWords !== false,
    };
}

function loadFont(api: JulGameSdlApi, fontPath: string, fontSize: number): number | null {
    if (!ttfAvailable(api)) {
        if (!ttfMissingWarned) {
            console.warn(
                "TextBox: SDL_ttf glue missing — rebuild WASM: npm run build:wasm --prefix ../../JulGame.jl/ts",
            );
            ttfMissingWarned = true;
        }
        return null;
    }
    const cacheKey = fontPath + ":" + fontSize;
    const existing = openFonts.get(cacheKey);
    if (existing) {
        return existing;
    }
    const font = api.glue_TTF_OpenFont!("/game/assets/fonts/" + fontPath, fontSize);
    if (!font) {
        console.warn(
            "TextBox: failed to load font " + fontPath + " size " + fontSize + ": " + (api.glue_SDL_GetError?.() ?? "unknown"),
        );
        return null;
    }
    openFonts.set(cacheKey, font);
    return font;
}

function getOrCreateTextTexture(
    api: JulGameSdlApi,
    ui: TextBoxElement,
    font: number,
): CachedTextTexture | null {
    const uiKey = String(ui.id);
    const contentKey = textureCacheKey(ui);
    const cached = textTextures.get(uiKey);
    if (cached && cached.key === contentKey) {
        (ui as { __lastTexStep?: string }).__lastTexStep = "texHit";
        return cached;
    }
    (ui as { __lastTexStep?: string }).__lastTexStep = "texMiss";
    const text = ui.text === "" ? " " : ui.text;
    const surface = api.glue_TTF_RenderUTF8_Blended!(font, text, ui.color[0], ui.color[1], ui.color[2], ui.color[3]);
    if (!surface) {
        return null;
    }
    const w = api.glue_surface_w(surface);
    const h = api.glue_surface_h(surface);
    const texture = api.glue_SDL_CreateTextureFromSurface(0, surface);
    api.glue_SDL_FreeSurface(surface);
    if (!texture) {
        return null;
    }
    if (cached?.texture) {
        api.glue_SDL_DestroyTexture?.(cached.texture);
    }
    const entry: CachedTextTexture = { key: contentKey, texture, w, h };
    textTextures.set(uiKey, entry);
    ui.textTexture = texture;
    ui.size = { x: w, y: h };
    if (!ui.originalSize || (ui.originalSize.x === 0 && ui.originalSize.y === 0)) {
        ui.originalSize = { x: w, y: h };
    }
    return entry;
}

export function UI_load_font(api: JulGameSdlApi, self: TextBoxElement, fontPath?: string): void {
    const path = fontPath ?? self.fontPath;
    if (!path) {
        return;
    }
    self.font = loadFont(api, path, self.fontSize);
    if (self.font) {
        getOrCreateTextTexture(api, self, self.font);
        if (!self.isWorldEntity) {
            UI_align_to_anchor(self);
        }
    }
}

export function UI_render_TextBox(api: JulGameSdlApi, self: TextBoxElement): void {
    const t0 = performance.now();
    const steps: Record<string, number> = {};
    const step = <T>(label: string, fn: () => T): T => {
        const s0 = performance.now();
        const result = fn();
        steps[label] = (steps[label] ?? 0) + (performance.now() - s0);
        return result;
    };
    if (!self.isActive || (globalThis as any).JulGame.IS_CHANGING_SCENE) {
        return;
    }
    if (!self.fontPath) {
        return;
    }
    const font = step("loadFont", () => self.font ?? loadFont(api, self.fontPath, self.fontSize));
    if (!font) {
        return;
    }
    self.font = font;
    const tex = step("texCache", () => getOrCreateTextTexture(api, self, font));
    const texStep = (self as { __lastTexStep?: string }).__lastTexStep;
    if (texStep) {
        steps[texStep] = (steps[texStep] ?? 0) + (steps["texCache"] ?? 0);
        delete steps["texCache"];
    }
    if (!tex) {
        return;
    }
    if (!self.isWorldEntity) {
        step("align", () => UI_align_to_anchor(self));
    }
    const renderCopy = api.glue_render_copy_ex_f;
    if (typeof renderCopy !== "function") {
        return;
    }
    step("colorMod", () => {
        api.glue_SDL_SetTextureColorMod?.(tex.texture, 255, 255, 255);
        api.glue_SDL_SetTextureAlphaMod?.(tex.texture, self.color[3]);
    });
    let x = self.position.x;
    let y = self.position.y;
    step("layout", () => {
        if (self.originalSize && self.originalSize !== self.size && self.anchor.current_state === "none") {
            x = self.position.x - (self.size.x - self.originalSize.x) / 2;
            y = self.position.y - (self.size.y - self.originalSize.y) / 2;
        }
        const cam = (globalThis as any).MAIN?.scene?.camera;
        if (self.isCenteredX && cam) {
            x -= tex.w / 2;
        }
        if (self.isCenteredY && cam) {
            y -= tex.h / 2;
        }
    });
    step("renderCopy", () => {
        renderCopy(tex.texture, 0, 0, 0, 0, 0, x, y, tex.w, tex.h, 0, 0, 0, 0);
    });
    (self as TextBoxElement & UiProfiledElement).__uiProfileSteps = steps;
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
"""
end
