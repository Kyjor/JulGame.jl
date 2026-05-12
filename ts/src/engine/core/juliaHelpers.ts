/** Julia-style helpers for transpiled TS (no direct JS/TS equivalent). */

/** Julia `time_ns()` — monotonic-ish time in nanoseconds for deltas (e.g. `(time_ns() - t0) / 1e6` ms). */
export function time_ns(): number {
    return performance.now() * 1e6
}

export function clamp(val: number, min: number, max: number): number {
    return Math.min(Math.max(val, min), max);
}

export function unsafe_string(ptr: number): string {
    return "nothing yet"
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
