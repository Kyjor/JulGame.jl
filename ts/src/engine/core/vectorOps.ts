/**
 * Julia Math / Vector2 / Vector3 operator semantics for plain `{x,y}` and `{x,y,z}` objects.
 * Mirrors `src/Math/Vector2.jl`, `Vector3.jl`, and mixed rules in `src/Math/Math.jl`.
 */

/** Result of vec* helpers (matches global `Vector2f` / `Vector3f` object shapes). */
export type VecResult = { x: number; y: number } | { x: number; y: number; z: number } | number;

function isNum(v: unknown): v is number {
    return typeof v === "number" && !Number.isNaN(v);
}

function isV2(v: unknown): v is { x: number; y: number } {
    return (
        typeof v === "object" &&
        v !== null &&
        "x" in v &&
        "y" in v &&
        typeof (v as { x: unknown }).x === "number" &&
        typeof (v as { y: unknown }).y === "number" &&
        !("z" in v)
    );
}

function isV3(v: unknown): v is { x: number; y: number; z: number } {
    return (
        typeof v === "object" &&
        v !== null &&
        "x" in v &&
        "y" in v &&
        "z" in v &&
        typeof (v as { x: unknown }).x === "number" &&
        typeof (v as { y: unknown }).y === "number" &&
        typeof (v as { z: unknown }).z === "number"
    );
}

export function vecNeg(v: unknown): VecResult {
    if (isNum(v)) return -v;
    if (isV2(v)) return { x: -v.x, y: -v.y };
    if (isV3(v)) return { x: -v.x, y: -v.y, z: -v.z };
    return v as VecResult;
}

export function vecAdd(a: unknown, b: unknown): VecResult {
    if (isNum(a) && isNum(b)) return a + b;
    if (isV3(a) && isV3(b)) return { x: a.x + b.x, y: a.y + b.y, z: a.z + b.z };
    if (isV2(a) && isV2(b)) return { x: a.x + b.x, y: a.y + b.y };
    if (isV3(a) && isV2(b)) return { x: a.x + b.x, y: a.y + b.y, z: a.z };
    if (isV2(a) && isV3(b)) return { x: a.x + b.x, y: a.y + b.y };
    if (isV2(a) && isNum(b)) return { x: a.x + b, y: a.y + b };
    if (isNum(a) && isV2(b)) return { x: b.x + a, y: b.y + a };
    if (isV3(a) && isNum(b)) return { x: a.x + b, y: a.y + b, z: a.z + b };
    if (isNum(a) && isV3(b)) return { x: b.x + a, y: b.y + a, z: b.z + a };
    return a as VecResult;
}

export function vecSub(a: unknown, b: unknown): VecResult {
    if (isNum(a) && isNum(b)) return a - b;
    if (isV3(a) && isV3(b)) return { x: a.x - b.x, y: a.y - b.y, z: a.z - b.z };
    if (isV2(a) && isV2(b)) return { x: a.x - b.x, y: a.y - b.y };
    if (isV3(a) && isV2(b)) return { x: a.x - b.x, y: a.y - b.y, z: a.z };
    if (isV2(a) && isV3(b)) return { x: a.x - b.x, y: a.y - b.y };
    if (isV2(a) && isNum(b)) return { x: a.x - b, y: a.y - b };
    if (isNum(a) && isV2(b)) return { x: a - b.x, y: a - b.y };
    if (isV3(a) && isNum(b)) return { x: a.x - b, y: a.y - b, z: a.z - b };
    if (isNum(a) && isV3(b)) return { x: a - b.x, y: a - b.y, z: a - b.z };
    return a as VecResult;
}

export function vecMul(a: unknown, b: unknown): VecResult {
    if (isNum(a) && isNum(b)) return a * b;
    if (isV3(a) && isV3(b)) return { x: a.x * b.x, y: a.y * b.y, z: a.z * b.z };
    if (isV2(a) && isV2(b)) return { x: a.x * b.x, y: a.y * b.y };
    if (isV3(a) && isV2(b)) return { x: a.x * b.x, y: a.y * b.y, z: a.z };
    if (isV2(a) && isV3(b)) return { x: a.x * b.x, y: a.y * b.y };
    if (isV2(a) && isNum(b)) return { x: a.x * b, y: a.y * b };
    if (isNum(a) && isV2(b)) return { x: b.x * a, y: b.y * a };
    if (isV3(a) && isNum(b)) return { x: a.x * b, y: a.y * b, z: a.z * b };
    if (isNum(a) && isV3(b)) return { x: b.x * a, y: b.y * a, z: b.z * a };
    return a as VecResult;
}

export function vecDiv(a: unknown, b: unknown): VecResult {
    if (isNum(a) && isNum(b)) return a / b;
    if (isV3(a) && isV3(b)) return { x: a.x / b.x, y: a.y / b.y, z: a.z / b.z };
    if (isV2(a) && isV2(b)) return { x: a.x / b.x, y: a.y / b.y };
    if (isV3(a) && isV2(b)) return { x: a.x / b.x, y: a.y / b.y, z: a.z };
    if (isV2(a) && isV3(b)) return { x: a.x / b.x, y: a.y / b.y };
    if (isV2(a) && isNum(b)) return { x: a.x / b, y: a.y / b };
    if (isNum(a) && isV2(b)) return { x: a / b.x, y: a / b.y };
    if (isV3(a) && isNum(b)) return { x: a.x / b, y: a.y / b, z: a.z / b };
    if (isNum(a) && isV3(b)) return { x: a / b.x, y: a / b.y, z: a / b.z };
    return a as VecResult;
}
