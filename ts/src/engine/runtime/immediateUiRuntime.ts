import { hydrateTextBoxFromJson, type TextBoxElement } from "../../../_generated/src/engine/UI/TextBox";
import { hydrateUiImageFromJson, type UiImageElement } from "../../../_generated/src/engine/UI/UIImage";
import { hydrateRectangleFromJson, type RectangleElement } from "../../../_generated/src/engine/UI/Rectangle";
import { UI_add_click_event } from "../../../_generated/src/engine/UI/UIElement";
import type { JulGameUiElement } from "../../../_generated/src/engine/UI/UiTypes";

export type ImmediateUiElement = TextBoxElement | UiImageElement | RectangleElement;

type ImmediateCacheEntry = {
    element: ImmediateUiElement;
    lifetime: number;
};

type ImmediateOpts = {
    text?: string;
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
    borderRadius?: number;
    fillMode?: boolean;
    name?: string;
};

const cache = new Map<string, ImmediateCacheEntry>();
/** Last `JulGame.FrameCount` when an immediate component was created/updated. */
const frameCounts = new Map<string, number>();
/** Last SDL tick (ms) when an immediate component was created/updated. */
const timestamps = new Map<string, number>();

/** Remove when not updated within 2 frames (Julia `DEFAULT_LIFETIME`). */
export const DEFAULT_LIFETIME = -1;
/** Never expire (Julia `INFINITE_LIFETIME`). */
export const INFINITE_LIFETIME = -2;

const DEFAULT_IMMEDIATE_FONT = "Century-Normal.ttf";

function currentFrameCount(): number {
    return (globalThis as { JulGame?: { FrameCount?: number } }).JulGame?.FrameCount ?? 0;
}

function currentTicks(): number {
    const api = (globalThis as { JulGameSdl?: { glue_SDL_GetTicks?: () => number } }).JulGameSdl;
    return api?.glue_SDL_GetTicks?.() ?? performance.now();
}

function touchImmediateComponent(compositeId: string): void {
    frameCounts.set(compositeId, currentFrameCount());
    timestamps.set(compositeId, currentTicks());
}

function removeFromScene(el: unknown): void {
    const list = sceneUiElements();
    const idx = list.indexOf(el);
    if (idx >= 0) {
        list.splice(idx, 1);
    }
}

export function removeImmediateComponent(compositeId: string): void {
    const entry = cache.get(compositeId);
    if (!entry) {
        return;
    }
    entry.element.isActive = false;
    removeFromScene(entry.element);
    cache.delete(compositeId);
    frameCounts.delete(compositeId);
    timestamps.delete(compositeId);
}

/**
 * Expire immediate UI not touched recently. Julia `manage_all_immediate_components` cleanup pass.
 * Call once per frame before the UI draw pass.
 */
export function manageAllImmediateComponents(): void {
    const frameCount = currentFrameCount();
    const now = currentTicks();
    const expired: string[] = [];

    for (const [compositeId, entry] of cache) {
        const { element, lifetime } = entry;
        if (lifetime === INFINITE_LIFETIME) {
            continue;
        }
        if (lifetime === DEFAULT_LIFETIME) {
            const lastFrame = frameCounts.get(compositeId);
            if (lastFrame === undefined || Math.abs(lastFrame - frameCount) > 2) {
                expired.push(compositeId);
            }
            continue;
        }
        if (lifetime >= 0) {
            const last = timestamps.get(compositeId);
            if (last === undefined || now - last > lifetime) {
                expired.push(compositeId);
            }
            continue;
        }
        if (!element.isActive) {
            expired.push(compositeId);
        }
    }

    for (const id of expired) {
        removeImmediateComponent(id);
    }
}

export function cleanupAllImmediateComponents(): void {
    for (const compositeId of [...cache.keys()]) {
        removeImmediateComponent(compositeId);
    }
}

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

function parseImmediateTextArgs(
    id: string,
    text: string,
    third?: unknown,
    ...rest: unknown[]
): { id: string; text: string; opts: ImmediateOpts } {
    const opts: ImmediateOpts = {};
    const tail = third !== undefined ? [third, ...rest] : [];
    if (tail.length === 1 && isImmediateOptsObject(tail[0])) {
        Object.assign(opts, tail[0]);
        return { id, text, opts };
    }
    if (tail.length > 0) {
        const [fontSize, anchor, anchorOffset, color, layer, parent] = tail;
        if (typeof fontSize === "number") {
            opts.fontSize = fontSize;
        }
        if (typeof anchor === "string") {
            opts.anchor = anchor;
        }
        if (anchorOffset && typeof anchorOffset === "object") {
            opts.anchorOffset = {
                x: Number((anchorOffset as { x?: number }).x ?? 0),
                y: Number((anchorOffset as { y?: number }).y ?? 0),
            };
        }
        if (Array.isArray(color) && color.length >= 4) {
            opts.color = [
                Number(color[0]),
                Number(color[1]),
                Number(color[2]),
                Number(color[3]),
            ];
        }
        if (typeof layer === "number") {
            opts.layer = layer;
        }
        if (parent !== undefined) {
            opts.parent = parent;
        }
    }
    return { id, text, opts };
}

function immediateText(id: string, text: string, opts: ImmediateOpts = {}): TextBoxElement;
function immediateText(id: string, text: string, third: unknown, ...rest: unknown[]): TextBoxElement;
function immediateText(id: string, text: string, third?: unknown, ...rest: unknown[]): TextBoxElement {
    const parsed =
        third !== undefined && (rest.length > 0 || isImmediateOptsObject(third))
            ? parseImmediateTextArgs(id, text, third, ...rest)
            : { id, text, opts: (third as ImmediateOpts | undefined) ?? {} };
    const resolvedId = parsed.id;
    const resolvedText = parsed.text;
    const opts = parsed.opts;
    const compositeId = `text_${resolvedId}`;
    const cached = cache.get(compositeId);
    if (cached?.element.type === "TextBox") {
        const el = cached.element as TextBoxElement;
        applyTextOpts(el, opts, resolvedText);
        wireClick(el, opts);
        wireHover(el, opts);
        touchImmediateComponent(compositeId);
        return el;
    }
    const el = hydrateTextBoxFromJson({
        id: compositeId,
        name: resolvedId,
        text: resolvedText,
        fontSize: opts.fontSize ?? 24,
        anchor: opts.anchor ?? "none",
        anchorOffset: opts.anchorOffset ?? { x: 0, y: 0 },
        fontPath: opts.fontPath ?? DEFAULT_IMMEDIATE_FONT,
        color: opts.color ?? [255, 255, 255, 255],
        layer: opts.layer ?? 0,
        isActive: opts.isActive ?? true,
        maxLineWidth: opts.maxLineWidth ?? 0,
        wrapWords: opts.wrapWords ?? true,
        parent: opts.parent ?? null,
    });
    wireClick(el, opts);
    wireHover(el, opts);
    const lifetime = opts.lifetime ?? DEFAULT_LIFETIME;
    cache.set(compositeId, { element: el, lifetime });
    touchImmediateComponent(compositeId);
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
        touchImmediateComponent(compositeId);
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
    const lifetime = opts.lifetime ?? DEFAULT_LIFETIME;
    cache.set(compositeId, { element: el, lifetime });
    touchImmediateComponent(compositeId);
    ensureInScene(el);
    return el;
}

function applyRectOpts(el: RectangleElement, opts: ImmediateOpts): void {
    if (opts.anchor !== undefined) el.anchor.current_state = opts.anchor;
    if (opts.anchorOffset !== undefined) el.anchorOffset = { ...opts.anchorOffset };
    if (opts.position !== undefined) el.position = { ...opts.position };
    if (opts.size !== undefined) el.size = { ...opts.size };
    if (opts.color !== undefined) el.color = parseColor(opts.color, el.color);
    if (opts.borderColor !== undefined) el.borderColor = parseColor(opts.borderColor, el.borderColor);
    if (opts.borderWidth !== undefined) el.borderWidth = opts.borderWidth;
    if (opts.borderRadius !== undefined) el.borderRadius = opts.borderRadius;
    if (opts.fillMode !== undefined) el.fillMode = opts.fillMode;
    if (opts.layer !== undefined) el.layer = opts.layer;
    if (opts.isActive !== undefined) el.isActive = opts.isActive;
    if (opts.parent !== undefined) el.parent = opts.parent;
    if (opts.forceClickCheck !== undefined) el.forceClickCheck = opts.forceClickCheck;
    if (opts.persistentBetweenScenes !== undefined) {
        el.persistentBetweenScenes = opts.persistentBetweenScenes;
    }
    if (opts.isWorldEntity !== undefined) el.isWorldEntity = opts.isWorldEntity;
}

function parseImmediateRectArgs(
    id: string,
    second?: unknown,
    ...rest: unknown[]
): { id: string; opts: ImmediateOpts } {
    const opts: ImmediateOpts = {};
    if (second !== undefined && isImmediateOptsObject(second)) {
        Object.assign(opts, second);
        return { id, opts };
    }

    const tail = second !== undefined ? [second, ...rest] : [];
    if (tail.length === 0) {
        return { id, opts };
    }

    const [a, b, c, d, e, f, g] = tail;
    if (typeof a === "string") {
        opts.anchor = a;
        const anchorOffset = parseSize(b);
        if (anchorOffset) {
            opts.anchorOffset = anchorOffset;
        }
        const size = parseSize(c);
        if (size) {
            opts.size = size;
        }
        if (Array.isArray(d) && d.length >= 4) {
            opts.color = [Number(d[0]), Number(d[1]), Number(d[2]), Number(d[3])];
        }
        if (typeof e === "number") {
            opts.layer = e;
        }
        return { id, opts };
    }

    const position = parseSize(a);
    if (position) {
        opts.position = position;
    }
    const size = parseSize(b);
    if (size) {
        opts.size = size;
    }
    if (Array.isArray(c) && c.length >= 4) {
        opts.color = [Number(c[0]), Number(c[1]), Number(c[2]), Number(c[3])];
    }
    if (typeof d === "number") {
        opts.borderWidth = d;
    }
    if (Array.isArray(e) && e.length >= 4) {
        opts.borderColor = [Number(e[0]), Number(e[1]), Number(e[2]), Number(e[3])];
    }
    if (typeof f === "number") {
        opts.layer = f;
    }
    if (typeof g === "number") {
        opts.borderRadius = g;
    }
    return { id, opts };
}

function immediateRect(id: string, opts?: ImmediateOpts): RectangleElement;
function immediateRect(id: string, second: unknown, ...rest: unknown[]): RectangleElement;
function immediateRect(id: string, second?: unknown, ...rest: unknown[]): RectangleElement {
    const parsed =
        second !== undefined && (rest.length > 0 || isImmediateOptsObject(second))
            ? parseImmediateRectArgs(id, second, ...rest)
            : { id, opts: (second as ImmediateOpts | undefined) ?? {} };
    const resolvedId = parsed.id;
    const opts = parsed.opts;
    const compositeId = `rect_${resolvedId}`;
    const cached = cache.get(compositeId);
    if (cached?.element.type === "Rectangle") {
        const el = cached.element as RectangleElement;
        applyRectOpts(el, opts);
        wireClick(el, opts);
        wireHover(el, opts);
        touchImmediateComponent(compositeId);
        return el;
    }
    const el = hydrateRectangleFromJson({
        id: `immediate_${resolvedId}`,
        name: opts.name ?? resolvedId,
        anchor: opts.anchor ?? "none",
        anchorOffset: opts.anchorOffset ?? { x: 0, y: 0 },
        position: opts.position ?? { x: 0, y: 0 },
        size: opts.size ?? { x: 1, y: 1 },
        color: opts.color ?? [255, 255, 255, 255],
        borderColor: opts.borderColor ?? [0, 0, 0, 255],
        borderWidth: opts.borderWidth ?? 0,
        borderRadius: opts.borderRadius ?? 0,
        fillMode: opts.fillMode ?? true,
        layer: opts.layer ?? 0,
        isActive: opts.isActive ?? true,
        parent: opts.parent ?? null,
        forceClickCheck: opts.forceClickCheck ?? false,
        isWorldEntity: opts.isWorldEntity ?? false,
        persistentBetweenScenes: opts.persistentBetweenScenes ?? false,
    });
    wireClick(el, opts);
    wireHover(el, opts);
    const lifetime = opts.lifetime ?? DEFAULT_LIFETIME;
    cache.set(compositeId, { element: el, lifetime });
    touchImmediateComponent(compositeId);
    ensureInScene(el);
    return el;
}

function isImmediateOptsObject(value: unknown): value is ImmediateOpts {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
        return false;
    }
    const o = value as Record<string, unknown>;
    return (
        "text" in o ||
        "fontSize" in o ||
        "anchor" in o ||
        "anchorOffset" in o ||
        "size" in o ||
        "layer" in o ||
        "parent" in o ||
        "color" in o ||
        "position" in o ||
        "borderWidth" in o ||
        "borderRadius" in o
    );
}

function parseSize(value: unknown): { x: number; y: number } | undefined {
    if (!value || typeof value !== "object") {
        return undefined;
    }
    const o = value as { x?: number; y?: number };
    if (typeof o.x === "number" && typeof o.y === "number") {
        return { x: o.x, y: o.y };
    }
    return undefined;
}

/** Julia `immediate_button` — clickable panel + centered label (stripped ScreenButton stand-in). */
function immediateButton(
    id: string,
    clickEvent?: (() => void) | null,
    third?: unknown,
    ...rest: unknown[]
): UiImageElement {
    const opts: ImmediateOpts = {};
    if (typeof clickEvent === "function") {
        opts.clickEvent = clickEvent;
    }

    const tail = third !== undefined ? [third, ...rest] : [];
    if (tail.length === 1 && isImmediateOptsObject(tail[0])) {
        Object.assign(opts, tail[0]);
    } else if (tail.length > 0) {
        const [text, fontSize, size, anchor, anchorOffset, color, layer, parent] = tail;
        if (typeof text === "string") {
            opts.text = text;
        }
        if (typeof fontSize === "number") {
            opts.fontSize = fontSize;
        }
        const parsedSize = parseSize(size);
        if (parsedSize) {
            opts.size = parsedSize;
        }
        if (typeof anchor === "string") {
            opts.anchor = anchor;
        }
        if (anchorOffset && typeof anchorOffset === "object") {
            opts.anchorOffset = {
                x: Number((anchorOffset as { x?: number }).x ?? 0),
                y: Number((anchorOffset as { y?: number }).y ?? 0),
            };
        }
        if (Array.isArray(color) && color.length >= 4) {
            opts.color = [
                Number(color[0]),
                Number(color[1]),
                Number(color[2]),
                Number(color[3]),
            ];
        }
        if (typeof layer === "number") {
            opts.layer = layer;
        }
        if (parent !== undefined) {
            opts.parent = parent;
        }
    }

    const button = immediateImage(id, "ui-newgamebox-0000.png", {
        ...opts,
        size: opts.size ?? { x: 200, y: 60 },
        layer: (opts.layer ?? 0) + 1,
        forceClickCheck: opts.forceClickCheck ?? true,
    });

    const label = opts.text ?? "";
    if (label.length > 0) {
        immediateText(`${id}_label`, label, {
            fontSize: opts.fontSize ?? 24,
            anchor: "center",
            color: [255, 255, 255, 255],
            layer: opts.layer ?? 0,
            parent: button,
            isActive: opts.isActive,
            persistentBetweenScenes: opts.persistentBetweenScenes,
        });
    }

    return button;
}

export function installImmediateUi(jg: Record<string, unknown>): void {
    jg.ImmediateUIModule = {
        DEFAULT_LIFETIME,
        INFINITE_LIFETIME,
        immediate_text: immediateText,
        immediate_image: immediateImage,
        immediate_rect: immediateRect,
        immediate_button: immediateButton,
        manage_all_immediate_components: manageAllImmediateComponents,
        cleanup_all_immediate_components: cleanupAllImmediateComponents,
        remove_immediate_component: removeImmediateComponent,
    };
}

export function clearImmediateUiCache(): void {
    cleanupAllImmediateComponents();
    cache.clear();
    frameCounts.clear();
    timestamps.clear();
}
