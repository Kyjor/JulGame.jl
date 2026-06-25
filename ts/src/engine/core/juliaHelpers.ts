/** Julia-style helpers for transpiled TS (no direct JS/TS equivalent). */

/** Julia `time_ns()` — monotonic-ish time in nanoseconds for deltas (e.g. `(time_ns() - t0) / 1e6` ms). */
export function time_ns(): number {
    return performance.now() * 1e6
}

export function clamp(val: number, min: number, max: number): number {
    return Math.min(Math.max(val, min), max);
}

export function strip(value: unknown): string {
    return String(value).trim();
}

/** Julia `replace(str, pattern => repl)` — string or regex pattern. */
export function replace(
    str: unknown,
    pattern: string | RegExp,
    replacement: string,
): string {
    const s = String(str);
    if (pattern instanceof RegExp) {
        return s.replace(pattern, replacement);
    }
    return s.split(pattern).join(replacement);
}

export function lowercase(value: unknown): string {
    return String(value).toLowerCase();
}

export function uppercase(value: unknown): string {
    return String(value).toUpperCase();
}

/** Julia `startswith(haystack, prefix)`. */
export function startswith(haystack: unknown, prefix: unknown): boolean {
    return String(haystack).startsWith(String(prefix));
}

/** Julia `split(str, delim)` — `delim` is a string or regex-like pattern string. */
export function split(value: unknown, delim: string | RegExp): string[] {
    if (delim instanceof RegExp) {
        return String(value).split(delim);
    }
    if (delim.length === 1) {
        return String(value).split(delim);
    }
    return String(value).split(delim);
}

/** Julia `filter(f, collection)` — predicate first, unlike `Array.prototype.filter`. */
export function filter(
    fn: (item: unknown, index?: number) => boolean,
    collection: unknown,
): unknown[] {
    if (Array.isArray(collection)) {
        return collection.filter((item, index) => fn(item, index));
    }
    if (collection instanceof Map) {
        return [...collection.entries()].filter((entry) => fn(entry));
    }
    if (collection != null && typeof collection === "object") {
        return Object.entries(collection as Record<string, unknown>).filter((entry) => fn(entry));
    }
    return [];
}

/** Julia `collect(iterable)` — values from dict-like collections into an array. */
export function collect(collection: unknown): unknown[] {
    if (Array.isArray(collection)) {
        return [...collection];
    }
    if (collection instanceof Map) {
        return [...collection.values()];
    }
    if (collection != null && typeof collection === "object") {
        return Object.values(collection as Record<string, unknown>);
    }
    return [];
}

/** Julia `get(collection, key[, default])` for objects and `Map`. */
export function get(
    collection: unknown,
    key: string | number,
    defaultValue?: unknown,
): unknown {
    if (collection == null) {
        return defaultValue;
    }
    if (collection instanceof Map) {
        return collection.has(key) ? collection.get(key) : defaultValue;
    }
    if (typeof collection === "object") {
        const rec = collection as Record<string | number, unknown>;
        return Object.prototype.hasOwnProperty.call(rec, key) ? rec[key] : defaultValue;
    }
    return defaultValue;
}

/** Julia `mod(x, y)` — remainder with the sign of `y` (floored division). */
export function mod(x: number, y: number): number {
    if (y === 0) {
        return NaN;
    }
    return x - y * Math.floor(x / y);
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

const objectIdMap = new WeakMap<object, number>();
let nextObjectId = 1;

/** Julia `objectid(x)` — stable numeric id per object (for Set dedup). */
export function objectid(obj: unknown): number {
    if (obj == null || typeof obj !== "object") {
        return 0;
    }
    const key = obj as object;
    let id = objectIdMap.get(key);
    if (id === undefined) {
        id = nextObjectId++;
        objectIdMap.set(key, id);
    }
    return id;
}

/** Julia `hasproperty(obj, :field)` — own property check on objects. */
export function hasproperty(obj: unknown, key: string | number): boolean {
    if (obj == null || typeof obj !== "object") {
        return false;
    }
    return Object.prototype.hasOwnProperty.call(obj, key);
}

/**
 * Julia `hasfield(T, :field)` — transpiled code often passes `typeof(x)` (a string).
 * For string first args, treat as the Julia compile-time check (field exists on instances).
 */
export function hasfield(typeOrObj: unknown, field: string | number): boolean {
    if (typeOrObj != null && typeof typeOrObj === "object") {
        return hasproperty(typeOrObj, field);
    }
    return typeof typeOrObj === "string";
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
/** Julia `dirname(path)` — parent directory of a file path. */
export function dirname(path: string): string {
    const n = String(path).replace(/\\/g, "/");
    const i = n.lastIndexOf("/");
    if (i <= 0) {
        return i === 0 ? "/" : ".";
    }
    return n.slice(0, i);
}

/** Julia `isfile(path)` — web uses PrefHandler local storage when available. */
export function isfile(path: string): boolean {
    const pref = (globalThis as {
        JulGame?: { PrefHandlerModule?: { file_exists?: (p: string) => boolean; read_text?: (p: string) => string | null } };
    }).JulGame?.PrefHandlerModule;
    if (pref?.file_exists) {
        return pref.file_exists(path);
    }
    if (pref?.read_text) {
        try {
            return pref.read_text(path) != null;
        } catch {
            return false;
        }
    }
    return false;
}

/** Julia `isdir(path)` — no real dirs in browser prefs; treat as exists. */
export function isdir(_path: string): boolean {
    return true;
}

/** Julia `mkpath(path)` — noop for browser-backed prefs. */
export function mkpath(_path: string): void {}

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
