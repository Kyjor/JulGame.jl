# ScreenButton.jl → ScreenButton.ts (Julia UI.render / UI.initialize paths).

function is_screenbutton_source(path_jl::AbstractString)::Bool
    return endswith(replace(normpath(String(path_jl)), '\\' => '/'), "/src/engine/UI/ScreenButton.jl")
end

function postprocess_screenbutton_ts(_data::AbstractString)::String
    return """
import type { JulGameSdlApi } from "../../../../src/platform/sdl-wasm/SDLBridge";
import { normalizeAssetPath } from "../../../../src/engine/runtime/projectConfig";
import { UI_align_to_anchor } from "./UIElement";
import { parseJuliaUiColor, type JulGameUiElement } from "./uiTypes";
import { loadUiTextureFromPath, isUiTextureHandleCurrent } from "./UIImage";

export type ScreenButtonElement = JulGameUiElement & {
    type: "ScreenButton";
    buttonUpSpritePath: string;
    buttonDownSpritePath: string;
    buttonUpTexture: number | null;
    buttonDownTexture: number | null;
    currentTexture: number | null;
    isInitialized: boolean;
    isHovered: boolean;
    rotation: number;
    text: string;
    fontPath: string | null;
    fontSize: number;
    textTexture: number | null;
    textOffset: { x: number; y: number };
    textSize: { x: number; y: number };
    textColor: [number, number, number, number];
};

export function hydrateScreenButtonFromJson(json: Record<string, unknown>): ScreenButtonElement {
    return {
        type: "ScreenButton",
        id: (json.id as string | number) ?? 0,
        name: String(json.name ?? "Button"),
        buttonUpSpritePath: normalizeAssetPath(String(json.buttonUpSpritePath ?? json.path ?? "")),
        buttonDownSpritePath: normalizeAssetPath(String(json.buttonDownSpritePath ?? json.buttonUpSpritePath ?? json.path ?? "")),
        position: (json.position as { x: number; y: number }) ?? { x: 0, y: 0 },
        size: (json.size as { x: number; y: number }) ?? { x: 0, y: 0 },
        originalSize: (json.size as { x: number; y: number }) ?? { x: 0, y: 0 },
        layer: typeof json.layer === "number" ? json.layer : 0,
        isActive: json.isActive !== false,
        color: parseJuliaUiColor(json.color, typeof json.alpha === "number" ? json.alpha : 255),
        textColor: parseJuliaUiColor(json.textColor ?? json.color, 255),
        persistentBetweenScenes: !!json.persistentBetweenScenes,
        isWorldEntity: json.isWorldEntity === true,
        anchor: { current_state: String(json.anchor ?? "none") },
        anchorOffset: (json.anchorOffset as { x: number; y: number }) ?? { x: 0, y: 0 },
        parent: json.parent ?? null,
        clickEvents: [],
        hoverEnterEvents: [],
        hoverExitEvents: [],
        buttonUpTexture: null,
        buttonDownTexture: null,
        currentTexture: null,
        isInitialized: false,
        isHovered: false,
        rotation: typeof json.rotation === "number" ? json.rotation : 0,
        text: String(json.text ?? ""),
        fontPath: typeof json.fontPath === "string" ? normalizeAssetPath(json.fontPath) : null,
        fontSize: typeof json.fontSize === "number" ? json.fontSize : 24,
        textTexture: null,
        textOffset: (json.textOffset as { x: number; y: number }) ?? { x: 0, y: 0 },
        textSize: { x: 0, y: 0 },
    };
}

export function UI_initialize_ScreenButton(api: JulGameSdlApi, self: ScreenButtonElement): void {
    if (self.isInitialized) {
        return;
    }
    self.buttonUpTexture = loadUiTextureFromPath(api, self.buttonUpSpritePath);
    self.buttonDownTexture = loadUiTextureFromPath(api, self.buttonDownSpritePath);
    self.currentTexture = self.buttonUpTexture;
    if (self.size.x === 0 && self.size.y === 0 && self.buttonUpTexture) {
        const w = api.glue_texture_w?.(self.buttonUpTexture) ?? 0;
        const h = api.glue_texture_h?.(self.buttonUpTexture) ?? 0;
        if (w > 0 && h > 0) {
            self.size = { x: w, y: h };
            self.originalSize = { x: w, y: h };
        }
    }
    if (!self.isWorldEntity) {
        UI_align_to_anchor(self);
    }
    self.isInitialized = true;
}

export function UI_render_ScreenButton(api: JulGameSdlApi, self: ScreenButtonElement): void {
    if (!self.isActive || (globalThis as any).JulGame.IS_CHANGING_SCENE) {
        return;
    }
    if (!self.isInitialized || !isUiTextureHandleCurrent(self.buttonUpSpritePath, self.buttonUpTexture)) {
        self.isInitialized = false;
        self.buttonUpTexture = null;
        self.buttonDownTexture = null;
        self.currentTexture = null;
        UI_initialize_ScreenButton(api, self);
    }
    if (!self.currentTexture) {
        return;
    }
    if (self.currentTexture === self.buttonDownTexture && !self.isHovered && self.buttonUpTexture) {
        self.currentTexture = self.buttonUpTexture;
    }
    if (!self.isWorldEntity) {
        UI_align_to_anchor(self);
    }
    const renderCopyEx = api.glue_render_copy_ex;
    if (typeof renderCopyEx !== "function") {
        return;
    }
    api.glue_SDL_SetTextureColorMod?.(self.currentTexture, self.color[0], self.color[1], self.color[2]);
    api.glue_SDL_SetTextureAlphaMod?.(self.currentTexture, self.color[3]);
    const x = Math.round(self.position.x);
    const y = Math.round(self.position.y);
    const w = Math.round(self.size.x);
    const h = Math.round(self.size.y);
    renderCopyEx(self.currentTexture, 0, 0, 0, 0, 0, x, y, w, h, 0, 0, 0, 0);
}
"""
end
