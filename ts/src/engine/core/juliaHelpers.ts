/** Julia-style helpers for transpiled TS (no direct JS/TS equivalent). */

/** Julia `time_ns()` — monotonic-ish time in nanoseconds for deltas (e.g. `(time_ns() - t0) / 1e6` ms). */
export function time_ns(): number {
    return performance.now() * 1e6
}

export function clamp(val: number, min: number, max: number): number {
    return Math.min(Math.max(val, min), max);
}

/** SDL_mixer volume: Julia `-1` means default (128), not silent. */
export function mixVolume(volume: number): number {
    return volume < 0 ? 128 : clamp(volume, 0, 128);
}

/** Julia `pointer(arr)` — copy bytes into wasm-owned memory for SDL_RWFromConstMem / similar. */
export function pointer(data: Uint8Array | ArrayLike<number>): number {
    const bytes = data instanceof Uint8Array ? data : Uint8Array.from(data as ArrayLike<number>);
    const alloc = (globalThis as { JulGameSdl?: { glue_wasm_alloc_copy?: (buf: Uint8Array, len: number) => number } })
        .JulGameSdl?.glue_wasm_alloc_copy;
    if (!alloc) {
        throw new Error("pointer(): glue_wasm_alloc_copy not available (rebuild wasm)");
    }
    return alloc(bytes, bytes.length);
}

/** Julia `haskey(dict, key)` — works for plain objects and `Map`. */
export function haskey(collection: unknown, key: string | number): boolean {
    if (collection == null) {
        return false;
    }
    if (collection instanceof Map) {
        return collection.has(key);
    }
    if (typeof collection === "object") {
        return Object.prototype.hasOwnProperty.call(collection, key);
    }
    return false;
}

/** Julia `unsafe_string` — decode a C string pointer, or pass through wasm cwrap `"string"` results. */
export function unsafe_string(ptr: number | string | null | undefined): string {
    if (ptr == null) {
        return "";
    }
    if (typeof ptr === "string") {
        return ptr;
    }
    if (ptr === 0) {
        return "";
    }
    const sdl = (globalThis as { JulGameSdl?: { UTF8ToString?: (p: number) => string } }).JulGameSdl;
    if (sdl?.UTF8ToString) {
        return sdl.UTF8ToString(ptr);
    }
    return "";
}

/**
 * Julia `unsafe_wrap(Array, ptr, n, own)` for SDL surface pointers.
 * Transpiled code reads `surface[0].w` / `surface[0].h` after wrapping.
 */
export function unsafe_wrap(
    _arrayType: unknown,
    ptr: number | null | undefined,
    _count?: number,
    _own?: boolean,
): Array<{ w: number; h: number }> {
    if (ptr == null || ptr === 0) {
        return [{ w: 0, h: 0 }]
    }
    const sdl = (globalThis as { JulGameSdl?: { glue_surface_w?: (p: number) => number; glue_surface_h?: (p: number) => number } })
        .JulGameSdl
    if (sdl?.glue_surface_w && sdl?.glue_surface_h) {
        return [{ w: sdl.glue_surface_w(ptr), h: sdl.glue_surface_h(ptr) }]
    }
    return [{ w: 0, h: 0 }]
}
export function joinpath(...parts: string[]): string {
    if (parts.length === 0) return ""
    const normalized = parts.map((p) => String(p).replace(/\\/g, "/"))
    let out = normalized[0]
    for (let i = 1; i < normalized.length; i++) {
        let seg = normalized[i]
        if (seg === "") continue
        seg = seg.replace(/^\//, "")
        if (out === "") {
            out = seg
            continue
        }
        out = out.endsWith("/") ? out + seg : `${out}/${seg}`
    }
    return out.replace(/\/+/g, "/")
}
