/** Julia-style helpers for transpiled TS (no direct JS/TS equivalent). */

export function clamp(val: number, min: number, max: number): number {
    return Math.min(Math.max(val, min), max);
}

export function unsafe_string(ptr: number): string {
    return "nothing yet"
}
