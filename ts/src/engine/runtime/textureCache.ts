import type { JulGameSdlApi } from "../../platform/sdl-wasm/SDLBridge";
import type { Scene } from "../../../_generated/src/engine/Scene";
import type { Entity } from "../../../_generated/src/engine/Entity";
import { evictUiImageTextureForPath } from "../../../_generated/src/engine/UI/UIImage";

type SpriteLike = { imagePath?: string; texture?: number | null };

function spriteTextureCache(): Record<string, number> | undefined {
    return (globalThis as { JulGame?: { TEXTURE_CACHE?: Record<string, number> } }).JulGame?.TEXTURE_CACHE;
}

/** Drop a shared sprite texture and remove it from TEXTURE_CACHE. */
export function evictSpriteTextureForPath(imagePath: string, api: JulGameSdlApi): void {
    if (!imagePath) {
        return;
    }
    const cache = spriteTextureCache();
    if (!cache) {
        return;
    }
    const tex = cache[imagePath];
    if (!tex) {
        return;
    }
    api.glue_SDL_DestroyTexture?.(tex);
    delete cache[imagePath];
    bumpMemfsImageVersion(imagePath);
}

const memfsImageVersions = new Map<string, number>();

export function bumpMemfsImageVersion(imagePath: string): void {
    if (!imagePath) {
        return;
    }
    memfsImageVersions.set(imagePath, (memfsImageVersions.get(imagePath) ?? 0) + 1);
}

export function getMemfsImageVersion(imagePath: string): number {
    return memfsImageVersions.get(imagePath) ?? 0;
}

/** Clear stale sprite.texture handles after cache entries are destroyed. */
export function clearStaleSpriteTextureRefs(scene: Scene): void {
    const cache = spriteTextureCache();
    for (const entity of scene.entities as Entity[]) {
        const sp = entity.sprite as SpriteLike | null;
        if (!sp?.texture) {
            continue;
        }
        const path = sp.imagePath ?? "";
        if (!path || !cache?.[path] || cache[path] !== sp.texture) {
            sp.texture = null;
        }
    }
}

/** Null UI element texture fields so render paths reload after cache clears. */
export function clearUiElementTextureRefs(scene: Scene): void {
    for (const el of scene.uiElements as Array<Record<string, unknown>>) {
        switch (el.type) {
            case "UIImage":
                el.texture = null;
                break;
            case "ScreenButton":
                el.buttonUpTexture = null;
                el.buttonDownTexture = null;
                el.currentTexture = null;
                el.isInitialized = false;
                break;
            case "TextBox":
                el.textTexture = null;
                break;
            default:
                break;
        }
    }
}

/** Invalidate cached GPU textures when MEMFS image bytes change (placeholder → real asset). */
export function invalidateTextureCachesForImagePath(imagePath: string, api: JulGameSdlApi): void {
    evictSpriteTextureForPath(imagePath, api);
    evictUiImageTextureForPath(api, imagePath);
}
