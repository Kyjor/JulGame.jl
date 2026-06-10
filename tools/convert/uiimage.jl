# UIImage.jl → UIImage.ts (render path from Julia UI.render, SDL via glue).

function is_uiimage_source(path_jl::AbstractString)::Bool
    return endswith(replace(normpath(String(path_jl)), '\\' => '/'), "/src/engine/UI/UIImage.jl")
end

function postprocess_uiimage_ts(_data::AbstractString)::String
    return """
import type { JulGameSdlApi } from "../../../../src/platform/sdl-wasm/SDLBridge";
import { scheduleImageFetch } from "../../../../src/engine/runtime/memfsImage";
import { normalizeAssetPath } from "../../../../src/engine/runtime/projectConfig";
import type { UiProfiledElement } from "../../../../src/engine/runtime/uiDrawProfile";
import { UI_align_to_anchor } from "./UIElement";
import { parseJuliaUiColor, type JulGameUiElement } from "./uiTypes";

export type UiImageElement = JulGameUiElement & {
    type: "UIImage";
    path: string;
    rotation: number;
    isFlipped: boolean;
    texture: number | null;
    forceClickCheck?: boolean;
};

const imageTextures = new Map<string, number>();

export function hydrateUiImageFromJson(json: Record<string, unknown>): UiImageElement {
    return {
        type: "UIImage",
        id: (json.id as string | number) ?? 0,
        name: String(json.name ?? "Image"),
        path: normalizeAssetPath(String(json.path ?? "")),
        position: (json.position as { x: number; y: number }) ?? { x: 0, y: 0 },
        size: (json.size as { x: number; y: number }) ?? { x: 0, y: 0 },
        originalSize: (json.originalSize as { x: number; y: number }) ?? (json.size as { x: number; y: number }) ?? { x: 0, y: 0 },
        layer: typeof json.layer === "number" ? json.layer : 0,
        isActive: json.isActive !== false,
        isFlipped: !!json.isFlipped,
        rotation: typeof json.rotation === "number" ? json.rotation : 0,
        color: parseJuliaUiColor(json.color, typeof json.alpha === "number" ? json.alpha : 255),
        persistentBetweenScenes: !!json.persistentBetweenScenes,
        isWorldEntity: json.isWorldEntity === true,
        anchor: { current_state: String(json.anchor ?? "none") },
        anchorOffset: (json.anchorOffset as { x: number; y: number }) ?? { x: 0, y: 0 },
        parent: json.parent ?? null,
        clickEvents: [],
        hoverEnterEvents: [],
        hoverExitEvents: [],
        texture: null,
        forceClickCheck: !!json.forceClickCheck,
    };
}

export function loadUiTextureFromPath(api: JulGameSdlApi, imagePath: string): number | null {
    const cached = imageTextures.get(imagePath);
    if (cached) {
        return cached;
    }
    const fullPath = "/game/assets/images/" + imagePath;
    let surface = api.glue_IMG_Load(fullPath);
    if (!surface) {
        scheduleImageFetch(imagePath);
        surface = api.glue_IMG_Load(fullPath);
    }
    if (!surface) {
        return null;
    }
    const tex = api.glue_SDL_CreateTextureFromSurface(0, surface);
    api.glue_SDL_FreeSurface(surface);
    if (!tex) {
        console.warn("UIImage: CreateTextureFromSurface failed for " + fullPath, api.glue_SDL_GetError?.());
        return null;
    }
    imageTextures.set(imagePath, tex);
    return tex;
}

export function UI_initialize_UIImage(api: JulGameSdlApi, self: UiImageElement): void {
    if (!self.path) {
        return;
    }
    self.texture = loadUiTextureFromPath(api, self.path);
    if (self.size.x === 0 && self.size.y === 0 && self.texture) {
        const w = api.glue_texture_w?.(self.texture) ?? 0;
        const h = api.glue_texture_h?.(self.texture) ?? 0;
        if (w > 0 && h > 0) {
            self.size = { x: w, y: h };
            self.originalSize = { x: w, y: h };
        }
    }
}

function uiImageDebug(...args: unknown[]): void {
    if ((globalThis as { __JULGAME_DEBUG_UI_IMAGE?: boolean }).__JULGAME_DEBUG_UI_IMAGE) {
        console.log("[UIImage]", ...args);
    }
}

export function UI_render_UIImage(api: JulGameSdlApi, self: UiImageElement): void {
    const t0 = performance.now();
    const steps: Record<string, number> = {};
    const step = <T>(label: string, fn: () => T): T => {
        const s0 = performance.now();
        const result = fn();
        steps[label] = (steps[label] ?? 0) + (performance.now() - s0);
        return result;
    };
    const stashProfile = (bail?: string) => {
        (self as UiImageElement & UiProfiledElement).__uiProfileSteps = steps;
        uiImageDebug(self.name, bail ?? "ok", { path: self.path, texture: self.texture, steps });
    };
    if (!self.isActive || (globalThis as any).JulGame.IS_CHANGING_SCENE) {
        stashProfile("bail:inactive");
        return;
    }
    step("init", () => {
        if (!self.texture && self.path) {
            UI_initialize_UIImage(api, self);
        }
    });
    const texture = self.texture;
    if (!texture) {
        stashProfile("bail:noTexture");
        return;
    }
    if (!self.isWorldEntity) {
        step("align", () => UI_align_to_anchor(self));
    }
    step("colorMod", () => {
        const packed = api.glue_SDL_GetTextureColorMod_packed?.(texture);
        if (packed !== undefined) {
            const r = packed & 0xff;
            const g = (packed >> 8) & 0xff;
            const b = (packed >> 16) & 0xff;
            const a = (packed >> 24) & 0xff;
            if (r === self.color[0] && g === self.color[1] && b === self.color[2] && a === self.color[3]) {
                return;
            }
        }
        api.glue_SDL_SetTextureColorMod?.(texture, self.color[0], self.color[1], self.color[2]);
        api.glue_SDL_SetTextureAlphaMod?.(texture, self.color[3]);
    });
    const renderCopy = api.glue_render_copy_ex;
    if (typeof renderCopy !== "function") {
        stashProfile("bail:noRenderCopy");
        return;
    }
    const x = Math.round(self.position.x);
    const y = Math.round(self.position.y);
    const w = Math.round(self.size.x);
    const h = Math.round(self.size.y);
    step("renderCopy", () => {
        renderCopy(texture, 0, 0, 0, 0, 0, x, y, w, h, 0, 0, 0, self.isFlipped ? 1 : 0);
    });
    stashProfile();
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
"""
end
