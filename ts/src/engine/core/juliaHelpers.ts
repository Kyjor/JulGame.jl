/** Julia-style helpers for transpiled TS (no direct JS/TS equivalent). */

export function clamp(val: number, min: number, max: number): number {
    return Math.min(Math.max(val, min), max);
}

export function unsafe_string(ptr: number): string {
    return "nothing yet"
}

/** Julia `joinpath` — segments joined with `/` (browser / wasm asset paths). */
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
