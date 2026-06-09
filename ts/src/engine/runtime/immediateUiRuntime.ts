import { hydrateTextBoxFromJson, type TextBoxElement } from "../../../_generated/src/engine/UI/TextBox";
import { hydrateUiImageFromJson, type UiImageElement } from "../../../_generated/src/engine/UI/UIImage";
import { UI_add_click_event } from "../../../_generated/src/engine/UI/UIElement";
import type { JulGameUiElement } from "../../../_generated/src/engine/UI/uiTypes";

export type ImmediateUiElement = TextBoxElement | UiImageElement;

type ImmediateCacheEntry = {
    element: ImmediateUiElement;
    lifetime: number;
};

type ImmediateOpts = {
    fontSize?: number;
    anchor?: string;
    anchorOffset?: { x: number; y: number };
    fontPath?: string;
    color?: [number, number, number, number] | number[];
    lifetime?: number;
    layer?: number;
    size?: { x: number; y: number };
    isActive?: boolean;
    persistentBetweenScenes?: boolean;
    parent?: unknown;
    clickEvent?: () => void;
    hoverEnterEvent?: () => void;
    hoverExitEvent?: () => void;
    clickEvents?: Array<() => void>;
    maxLineWidth?: number;
    wrapWords?: boolean;
    forceClickCheck?: boolean;
    isWorldEntity?: boolean;
    position?: { x: number; y: number };
    borderWidth?: number;
    borderColor?: [number, number, number, number] | number[];
};

const cache = new Map<string, ImmediateCacheEntry>();

export const INFINITE_LIFETIME = -1;

function sceneUiElements(): unknown[] {
    const scene = (globalThis as { MAIN?: { scene?: { uiElements?: unknown[] } } }).MAIN?.scene;
    return scene?.uiElements ?? [];
}

function ensureInScene(el: unknown): void {
    const list = sceneUiElements();
    if (!list.includes(el)) {
        list.push(el);
    }
}

function parseColor(raw: unknown, fallback: [number, number, number, number]): [number, number, number, number] {
    if (Array.isArray(raw) && raw.length >= 4) {
        return [raw[0] ?? 255, raw[1] ?? 255, raw[2] ?? 255, raw[3] ?? 255];
    }
    return fallback;
}

function applyTextOpts(el: TextBoxElement, opts: ImmediateOpts, text: string): void {
    el.text = text;
    if (opts.fontSize !== undefined) el.fontSize = opts.fontSize;
    if (opts.anchor !== undefined) el.anchor.current_state = opts.anchor;
    if (opts.anchorOffset !== undefined) el.anchorOffset = { ...opts.anchorOffset };
    if (opts.fontPath !== undefined) el.fontPath = opts.fontPath;
    if (opts.color !== undefined) el.color = parseColor(opts.color, el.color);
    if (opts.layer !== undefined) el.layer = opts.layer;
    if (opts.isActive !== undefined) el.isActive = opts.isActive;
    if (opts.maxLineWidth !== undefined) el.maxLineWidth = opts.maxLineWidth;
    if (opts.wrapWords !== undefined) el.wrapWords = opts.wrapWords;
    if (opts.parent !== undefined) el.parent = opts.parent;
    if (opts.persistentBetweenScenes !== undefined) {
        el.persistentBetweenScenes = opts.persistentBetweenScenes;
    }
}

function applyImageOpts(el: UiImageElement, opts: ImmediateOpts, path?: string): void {
    if (path !== undefined && path !== el.path) {
        el.path = path;
        el.texture = null;
    }
    if (opts.anchor !== undefined) el.anchor.current_state = opts.anchor;
    if (opts.anchorOffset !== undefined) el.anchorOffset = { ...opts.anchorOffset };
    if (opts.size !== undefined) {
        el.size = { ...opts.size };
        el.originalSize = { ...opts.size };
    }
    if (opts.color !== undefined) el.color = parseColor(opts.color, el.color);
    if (opts.layer !== undefined) el.layer = opts.layer;
    if (opts.isActive !== undefined) el.isActive = opts.isActive;
    if (opts.parent !== undefined) el.parent = opts.parent;
    if (opts.position !== undefined) el.position = { ...opts.position };
    if (opts.forceClickCheck !== undefined) el.forceClickCheck = opts.forceClickCheck;
    if (opts.persistentBetweenScenes !== undefined) {
        el.persistentBetweenScenes = opts.persistentBetweenScenes;
    }
    if (opts.isWorldEntity !== undefined) el.isWorldEntity = opts.isWorldEntity;
}

function wireClick(el: JulGameUiElement, opts: ImmediateOpts): void {
    if (opts.clickEvent) {
        el.clickEvents.length = 0;
        UI_add_click_event(el, opts.clickEvent);
    } else if (opts.clickEvents?.length) {
        el.clickEvents.length = 0;
        for (const fn of opts.clickEvents) {
            UI_add_click_event(el, fn);
        }
    }
}

function wireHover(el: JulGameUiElement, opts: ImmediateOpts): void {
    if (opts.hoverEnterEvent) {
        el.hoverEnterEvents.length = 0;
        el.hoverEnterEvents.push(opts.hoverEnterEvent);
    }
    if (opts.hoverExitEvent) {
        el.hoverExitEvents.length = 0;
        el.hoverExitEvents.push(opts.hoverExitEvent);
    }
}

function immediateText(id: string, text: string, opts: ImmediateOpts = {}): TextBoxElement {
    const compositeId = `text_${id}`;
    const cached = cache.get(compositeId);
    if (cached?.element.type === "TextBox") {
        const el = cached.element as TextBoxElement;
        applyTextOpts(el, opts, text);
        wireClick(el, opts);
        wireHover(el, opts);
        return el;
    }
    const el = hydrateTextBoxFromJson({
        id: compositeId,
        name: id,
        text,
        fontSize: opts.fontSize ?? 24,
        anchor: opts.anchor ?? "none",
        anchorOffset: opts.anchorOffset ?? { x: 0, y: 0 },
        fontPath: opts.fontPath ?? "",
        color: opts.color ?? [255, 255, 255, 255],
        layer: opts.layer ?? 0,
        isActive: opts.isActive ?? true,
        maxLineWidth: opts.maxLineWidth ?? 0,
        wrapWords: opts.wrapWords ?? true,
        parent: opts.parent ?? null,
    });
    wireClick(el, opts);
    wireHover(el, opts);
    cache.set(compositeId, { element: el, lifetime: opts.lifetime ?? 60 });
    ensureInScene(el);
    return el;
}

function immediateImage(id: string, path: string, opts: ImmediateOpts = {}): UiImageElement {
    const compositeId = `image_${id}`;
    const cached = cache.get(compositeId);
    if (cached?.element.type === "UIImage") {
        const el = cached.element as UiImageElement;
        applyImageOpts(el, opts, path);
        wireClick(el, opts);
        wireHover(el, opts);
        return el;
    }
    const el = hydrateUiImageFromJson({
        id: compositeId,
        name: id,
        path,
        anchor: opts.anchor ?? "none",
        anchorOffset: opts.anchorOffset ?? { x: 0, y: 0 },
        size: opts.size ?? { x: 0, y: 0 },
        color: opts.color ?? [255, 255, 255, 255],
        layer: opts.layer ?? 0,
        isActive: opts.isActive ?? true,
        parent: opts.parent ?? null,
        forceClickCheck: opts.forceClickCheck ?? false,
        isWorldEntity: opts.isWorldEntity ?? false,
        position: opts.position ?? { x: 0, y: 0 },
    });
    wireClick(el, opts);
    wireHover(el, opts);
    cache.set(compositeId, { element: el, lifetime: opts.lifetime ?? 60 });
    ensureInScene(el);
    return el;
}

/** Colored hit/visual panel — uses a tinted box texture until Rectangle immediate UI exists. */
function immediateRect(id: string, opts: ImmediateOpts = {}): UiImageElement {
    return immediateImage(id, "ui-newgamebox-0000.png", {
        ...opts,
        forceClickCheck: opts.forceClickCheck ?? true,
    });
}

export function installImmediateUi(jg: Record<string, unknown>): void {
    jg.ImmediateUIModule = {
        INFINITE_LIFETIME,
        immediate_text: immediateText,
        immediate_image: immediateImage,
        immediate_rect: immediateRect,
    };
}

export function clearImmediateUiCache(): void {
    cache.clear();
}
