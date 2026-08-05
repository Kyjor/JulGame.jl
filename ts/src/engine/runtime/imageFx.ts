/**
 * Web ImageFX — clock-hand radial wipe for health hearts (ImageFX.jl gfx_clock_hand_sweep).
 * Mutates a private SDL texture per sprite; shared TEXTURE_CACHE path stays untouched.
 */

type SpriteLike = {
    imagePath?: string;
    texture?: number | null;
    image?: number | null;
    __clockSweepTex?: number | null;
    __clockSweepPercent?: number;
};

const originalImages = new Map<string, HTMLImageElement>();
const loadingImages = new Set<string>();
const lastPercent = new WeakMap<object, number>();

function clamp01(v: number): number {
    return Math.min(1, Math.max(0, v));
}

function assetUrl(imagePath: string): string | null {
    const base = String(
        (globalThis as { JulGame?: { memfsAssetBaseUrl?: string } }).JulGame?.memfsAssetBaseUrl ?? "",
    ).replace(/\/$/, "");
    if (!base || !imagePath) return null;
    return new URL(`assets/images/${imagePath}`, `${base}/`).href;
}

function ensureOriginalImage(imagePath: string): HTMLImageElement | null {
    const cached = originalImages.get(imagePath);
    if (cached?.complete && cached.naturalWidth > 0) return cached;
    if (loadingImages.has(imagePath)) return null;
    const url = assetUrl(imagePath);
    if (!url) return null;
    loadingImages.add(imagePath);
    const img = new Image();
    img.decoding = "async";
    img.onload = () => {
        originalImages.set(imagePath, img);
        loadingImages.delete(imagePath);
    };
    img.onerror = () => {
        loadingImages.delete(imagePath);
    };
    img.src = url;
    return null;
}

function dataUrlToBytes(dataUrl: string): Uint8Array {
    const b64 = dataUrl.split(",", 2)[1] ?? "";
    const bin = atob(b64);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
}

function uploadPngBytes(bytes: Uint8Array): number | null {
    const api = (globalThis as { JulGameSdl?: Record<string, any> }).JulGameSdl;
    const mod = (globalThis as { JulGame?: { emscriptenModule?: any } }).JulGame?.emscriptenModule
        ?? (globalThis as { Module?: any }).Module;
    if (!api?.glue_SDL_RWFromConstMem || !api?.glue_IMG_Load_RW || !api?.glue_SDL_CreateTextureFromSurface) {
        return null;
    }
    const ptr = mod?._malloc?.(bytes.length);
    if (!ptr || !mod.HEAPU8) return null;
    try {
        mod.HEAPU8.set(bytes, ptr);
        const rw = api.glue_SDL_RWFromConstMem(ptr, bytes.length);
        if (!rw) return null;
        const surface = api.glue_IMG_Load_RW(rw, 1);
        if (!surface) return null;
        // SDLBridge wraps C (surface-only) as (renderer, surface)
        const tex = api.glue_SDL_CreateTextureFromSurface(0, surface);
        api.glue_SDL_FreeSurface?.(surface);
        return tex || null;
    } finally {
        mod._free?.(ptr);
    }
}

function destroyPrivateTex(sprite: SpriteLike): void {
    const api = (globalThis as { JulGameSdl?: { glue_SDL_DestroyTexture?: (t: number) => void } }).JulGameSdl;
    if (sprite.__clockSweepTex && api?.glue_SDL_DestroyTexture) {
        api.glue_SDL_DestroyTexture(sprite.__clockSweepTex);
    }
    sprite.__clockSweepTex = null;
}

/** Apply clock-hand sweep; percentage 1 = full visible, 0 = fully hidden. */
export function gfx_clock_hand_sweep(
    sprite: SpriteLike | null | undefined,
    percentage: number,
    startAngle = 0.0,
    clockwise = true,
): void {
    if (sprite == null || !sprite.imagePath) return;
    const pct = clamp01(Number(percentage) || 0);
    const prev = lastPercent.get(sprite);
    if (prev === pct) return;

    const img = ensureOriginalImage(sprite.imagePath) ?? originalImages.get(sprite.imagePath);
    if (!img?.complete || img.naturalWidth <= 0) return;

    const w = img.naturalWidth;
    const h = img.naturalHeight;
    const canvas = document.createElement("canvas");
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.clearRect(0, 0, w, h);
    ctx.drawImage(img, 0, 0);

    if (pct < 1.0) {
        const cx = w / 2;
        const cy = h / 2;
        // Match Julia: 0° at top; hide from start across (1-pct)*360°
        const startRad = ((startAngle - 90) * Math.PI) / 180;
        const sweepRad = ((360.0 * (1.0 - pct)) * Math.PI) / 180;
        ctx.save();
        ctx.globalCompositeOperation = "destination-out";
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        if (clockwise) {
            ctx.arc(cx, cy, Math.max(w, h), startRad, startRad + sweepRad, false);
        } else {
            ctx.arc(cx, cy, Math.max(w, h), startRad, startRad - sweepRad, true);
        }
        ctx.closePath();
        ctx.fill();
        ctx.restore();
    }

    const bytes = dataUrlToBytes(canvas.toDataURL("image/png"));
    const tex = uploadPngBytes(bytes);
    if (!tex) return;

    destroyPrivateTex(sprite);
    sprite.__clockSweepTex = tex;
    // Keep sprite.image (surface) so Component_draw doesn't early-out / reload;
    // private texture overrides the shared TEXTURE_CACHE entry for this instance.
    sprite.texture = tex;
    lastPercent.set(sprite, pct);
    sprite.__clockSweepPercent = pct;
}

export function installImageFx(jg: Record<string, unknown>): void {
    const fx = (jg.FX ?? {}) as Record<string, unknown>;
    fx.ImageFXModule = {
        gfx_clock_hand_sweep: (
            sprite: SpriteLike,
            percentage: number,
            opts?: { start_angle?: number; clockwise?: boolean },
        ) =>
            gfx_clock_hand_sweep(
                sprite,
                percentage,
                opts?.start_angle ?? 0,
                opts?.clockwise ?? true,
            ),
    };
    jg.FX = fx;
}
