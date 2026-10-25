export type JulGameUiElement = {
    type: string;
    id: string | number;
    name: string;
    isActive: boolean;
    layer: number;
    persistentBetweenScenes: boolean;
    position: { x: number; y: number };
    size: { x: number; y: number };
    anchor: { current_state: string };
    anchorOffset: { x: number; y: number };
    parent: unknown;
    clickEvents: Array<() => void>;
    hoverEnterEvents: Array<() => void>;
    hoverExitEvents: Array<() => void>;
    color: [number, number, number, number];
    isWorldEntity?: boolean;
    originalSize?: { x: number; y: number };
};

export function parseJuliaUiColor(raw: unknown, alphaFallback = 255): [number, number, number, number] {
    if (Array.isArray(raw) && raw.length >= 3) {
        return [Number(raw[0]), Number(raw[1]), Number(raw[2]), Number(raw[3] ?? alphaFallback)];
    }
    if (raw && typeof raw === "object") {
        const o = raw as Record<string, number>;
        if ("r" in o && typeof o.r === "number") {
            return [o.r, o.g ?? 255, o.b ?? 255, o.a ?? alphaFallback];
        }
        // Scene JSON Math.Vector4: { x: r, y: g, z: b, t: a }
        if ("x" in o && typeof o.x === "number") {
            return [o.x, o.y ?? 255, o.z ?? 255, o.t ?? o.a ?? alphaFallback];
        }
        return [
            o["1"] ?? 255,
            o["2"] ?? 255,
            o["3"] ?? 255,
            o["4"] ?? alphaFallback,
        ];
    }
    return [255, 255, 255, alphaFallback];
}