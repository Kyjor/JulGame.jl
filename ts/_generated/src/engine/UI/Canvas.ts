import type { JulGameUiElement } from "./uiTypes";

export type SceneCanvas = JulGameUiElement & {
    type: "Canvas";
    children: JulGameUiElement[];
    clipChildren?: boolean;
};

export function hydrateCanvasFromJson(json: Record<string, unknown>): SceneCanvas {
    return {
        type: "Canvas",
        id: (json.id as string | number) ?? 0,
        name: String(json.name ?? "Canvas"),
        isActive: json.isActive !== false,
        layer: typeof json.layer === "number" ? json.layer : 0,
        persistentBetweenScenes: !!json.persistentBetweenScenes,
        position: (json.position as { x: number; y: number }) ?? { x: 0, y: 0 },
        size: (json.size as { x: number; y: number }) ?? { x: 0, y: 0 },
        anchor: { current_state: String(json.anchor ?? "none") },
        anchorOffset: (json.anchorOffset as { x: number; y: number }) ?? { x: 0, y: 0 },
        parent: json.parent ?? null,
        clickEvents: [],
        hoverEnterEvents: [],
        hoverExitEvents: [],
        color: [0, 0, 0, 0],
        children: [],
        clipChildren: !!json.clipChildren,
    };
}

export function add_child(canvas: SceneCanvas, child: JulGameUiElement): void {
    canvas.children.push(child);
    child.parent = canvas;
}

/** Build once per frame; O(1) lookup instead of scanning all canvases per element. */
export function buildInactiveCanvasHiddenSet(uiElements: unknown[]): Set<JulGameUiElement> {
    const hidden = new Set<JulGameUiElement>();
    for (const raw of uiElements) {
        const canvas = raw as SceneCanvas;
        if (canvas.type !== "Canvas" || !canvas.children?.length || canvas.isActive !== false) {
            continue;
        }
        for (const child of canvas.children) {
            hidden.add(child);
        }
    }
    return hidden;
}

/** Julia MainLoop: skip children of an inactive canvas. */
export function isUiHiddenByInactiveCanvas(ui: unknown, uiElements: unknown[]): boolean {
    return buildInactiveCanvasHiddenSet(uiElements).has(ui as JulGameUiElement);
}

export function shouldDrawUiElement(ui: { isActive?: boolean }, uiElements: unknown[]): boolean {
    if (ui.isActive === false) {
        return false;
    }
    return !isUiHiddenByInactiveCanvas(ui, uiElements);
}