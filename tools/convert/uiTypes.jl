# Shared UI element types emitted once for transpiled UI modules.

function is_ui_types_source(path_jl::AbstractString)::Bool
    norm = replace(normpath(String(path_jl)), '\\' => '/')
    return endswith(norm, "/src/engine/UI/UiTypes.jl") || endswith(norm, "/src/engine/UI/uiTypes.jl")
end

function postprocess_ui_types_ts(_data::AbstractString)::String
    return """
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
    if (raw && typeof raw === "object") {
        const o = raw as Record<string, number>;
        if ("r" in o && typeof o.r === "number") {
            return [o.r, o.g ?? 255, o.b ?? 255, o.a ?? alphaFallback];
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
"""
end
