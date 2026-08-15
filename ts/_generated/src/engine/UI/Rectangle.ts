import type { JulGameSdlApi } from "../../../../src/platform/sdl-wasm/SDLBridge";
import type { UiProfiledElement } from "../../../../src/engine/runtime/uiDrawProfile";
import { UI_align_to_anchor } from "./UIElement";
import { parseJuliaUiColor, type JulGameUiElement } from "./uiTypes";

export type RectangleElement = JulGameUiElement & {
    type: "Rectangle";
    fillMode: boolean;
    borderRadius: number;
    borderWidth: number;
    borderColor: [number, number, number, number];
    forceClickCheck?: boolean;
};

export function hydrateRectangleFromJson(json: Record<string, unknown>): RectangleElement {
    return {
        type: "Rectangle",
        id: (json.id as string | number) ?? 0,
        name: String(json.name ?? "Rectangle"),
        position: (json.position as { x: number; y: number }) ?? { x: 0, y: 0 },
        size: (json.size as { x: number; y: number }) ?? { x: 100, y: 100 },
        originalSize: (json.size as { x: number; y: number }) ?? { x: 100, y: 100 },
        layer: typeof json.layer === "number" ? json.layer : 0,
        isActive: json.isActive !== false,
        color: parseJuliaUiColor(json.color, typeof json.alpha === "number" ? json.alpha : 255),
        persistentBetweenScenes: !!json.persistentBetweenScenes,
        isWorldEntity: json.isWorldEntity === true,
        anchor: { current_state: String(json.anchor ?? "none") },
        anchorOffset: (json.anchorOffset as { x: number; y: number }) ?? { x: 0, y: 0 },
        parent: json.parent ?? null,
        clickEvents: [],
        hoverEnterEvents: [],
        hoverExitEvents: [],
        fillMode: json.fillMode !== false,
        borderRadius: typeof json.borderRadius === "number" ? json.borderRadius : 0,
        borderWidth: typeof json.borderWidth === "number" ? json.borderWidth : 0,
        borderColor: parseJuliaUiColor(json.borderColor, 255),
        forceClickCheck: !!json.forceClickCheck,
    };
}

export function UI_render_Rectangle(api: JulGameSdlApi, self: RectangleElement): void {
    const steps: Record<string, number> = {};
    const step = <T>(label: string, fn: () => T): T => {
        const s0 = performance.now();
        const result = fn();
        steps[label] = (steps[label] ?? 0) + (performance.now() - s0);
        return result;
    };
    const stashProfile = () => {
        (self as RectangleElement & UiProfiledElement).__uiProfileSteps = steps;
    };
    if (!self.isActive || (globalThis as any).JulGame?.IS_CHANGING_SCENE) {
        stashProfile();
        return;
    }
    if (!self.isWorldEntity) {
        step("align", () => UI_align_to_anchor(self));
    }
    const x = Math.round(self.position.x);
    const y = Math.round(self.position.y);
    const w = Math.round(self.size.x);
    const h = Math.round(self.size.y);
    if (w <= 0 || h <= 0) {
        stashProfile();
        return;
    }
    step("draw", () => {
        if (self.fillMode) {
            api.glue_SDL_SetRenderDrawColor?.(self.color[0], self.color[1], self.color[2], self.color[3]);
            api.glue_SDL_RenderFillRectF?.(x, y, w, h);
        }
        if (self.borderWidth > 0) {
            api.glue_SDL_SetRenderDrawColor?.(
                self.borderColor[0],
                self.borderColor[1],
                self.borderColor[2],
                self.borderColor[3],
            );
            // Approximate border with four thin fills.
            const bw = Math.max(1, Math.round(self.borderWidth));
            api.glue_SDL_RenderFillRectF?.(x, y, w, bw);
            api.glue_SDL_RenderFillRectF?.(x, y + h - bw, w, bw);
            api.glue_SDL_RenderFillRectF?.(x, y, bw, h);
            api.glue_SDL_RenderFillRectF?.(x + w - bw, y, bw, h);
        }
    });
    stashProfile();
}