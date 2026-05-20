import { loadSDLModule } from "./sdlModule";

type Cwrap = (
    ident: string,
    returnType: string | null,
    argTypes: string[],
) => (...args: unknown[]) => unknown;

type EmscriptenModuleShape = Record<string, unknown> & {
    cwrap?: Cwrap;
    FS?: {
        mkdirTree: (path: string) => void;
        writeFile: (path: string, data: Uint8Array | string, opts?: { canOwn?: boolean }) => void;
    };
};

/** Low-level C exports; TS layer adds rect helpers expected by generated JulGame code. */
type JulGameSdlCApi = {
    glue_init: (width: number, height: number) => number;
    glue_render_square_frame: () => void;
    glue_poll_quit: () => number;
    glue_SDL_GetTicks: () => number;
    glue_get_renderer: () => number;
    glue_SDL_RenderClear: () => void;
    glue_SDL_RenderPresent: () => void;
    glue_SDL_RenderSetLogicalSize: (w: number, h: number) => void;
    glue_SDL_SetRenderDrawBlendMode_BLEND: () => void;
    glue_SDL_SetRenderDrawColor: (r: number, g: number, b: number, a: number) => void;
    glue_SDL_RenderFillRectF: (x: number, y: number, w: number, h: number) => void;
    glue_IMG_Load: (path: string) => number;
    glue_SDL_CreateTextureFromSurface: (surface: number) => number;
    glue_SDL_FreeSurface: (surface: number) => void;
    glue_SDL_GetError: () => string;
    glue_SDL_ClearError: () => void;
    glue_surface_w: (surface: number) => number;
    glue_surface_h: (surface: number) => number;
    glue_SDL_SetTextureColorMod: (tex: number, r: number, g: number, b: number) => void;
    glue_SDL_SetTextureAlphaMod: (tex: number, a: number) => void;
    glue_render_copy_ex: (
        texture: number,
        has_src: number,
        sx: number,
        sy: number,
        sw: number,
        sh: number,
        dx: number,
        dy: number,
        dw: number,
        dh: number,
        angle: number,
        cx: number,
        cy: number,
        flip: number,
    ) => number;
    glue_render_copy_ex_f: (
        texture: number,
        has_src: number,
        sx: number,
        sy: number,
        sw: number,
        sh: number,
        dx: number,
        dy: number,
        dw: number,
        dh: number,
        angle: number,
        cx: number,
        cy: number,
        flip: number,
    ) => number;
};

/** API shape consumed by `_generated` engine code + wasm glue. */
export type JulGameSdlApi = JulGameSdlCApi & {
    glue_SDL_FRect: (x: number, y: number, w: number, h: number) => { x: number; y: number; w: number; h: number };
    glue_SDL_Rect: (x: number, y: number, w: number, h: number) => { x: number; y: number; w: number; h: number };
    glue_SDL_Point: (x: number, y: number) => { x: number; y: number };
    glue_SDL_FPoint: (x: number, y: number) => { x: number; y: number };
    glue_SDL_RenderCopyEx: (
        _renderer: number,
        texture: number,
        srcRect: { x: number; y: number; w: number; h: number } | null,
        dstRect: { x: number; y: number; w: number; h: number },
        angle: number,
        center: { x: number; y: number },
        flip: number,
    ) => number;
    glue_SDL_RenderCopyExF: (
        _renderer: number,
        texture: number,
        srcRect: { x: number; y: number; w: number; h: number } | null,
        dstRect: { x: number; y: number; w: number; h: number },
        angle: number,
        center: { x: number; y: number },
        flip: number,
    ) => number;
};

function wrapRenderCopyEx(
    c: JulGameSdlCApi["glue_render_copy_ex"],
): JulGameSdlApi["glue_SDL_RenderCopyEx"] {
    return (_renderer, texture, srcRect, dstRect, angle, center, flip) => {
        const hasSrc = srcRect && srcRect.w > 0 && srcRect.h > 0 ? 1 : 0;
        const sx = srcRect?.x ?? 0;
        const sy = srcRect?.y ?? 0;
        const sw = srcRect?.w ?? 0;
        const sh = srcRect?.h ?? 0;
        return c(
            texture,
            hasSrc,
            sx,
            sy,
            sw,
            sh,
            Math.round(dstRect.x),
            Math.round(dstRect.y),
            Math.round(dstRect.w),
            Math.round(dstRect.h),
            angle,
            Math.round(center.x),
            Math.round(center.y),
            flip,
        );
    };
}

function wrapRenderCopyExF(
    c: JulGameSdlCApi["glue_render_copy_ex_f"],
): JulGameSdlApi["glue_SDL_RenderCopyExF"] {
    return (_renderer, texture, srcRect, dstRect, angle, center, flip) => {
        const hasSrc = srcRect && srcRect.w > 0 && srcRect.h > 0 ? 1 : 0;
        const sx = srcRect?.x ?? 0;
        const sy = srcRect?.y ?? 0;
        const sw = srcRect?.w ?? 0;
        const sh = srcRect?.h ?? 0;
        return c(
            texture,
            hasSrc,
            sx,
            sy,
            sw,
            sh,
            dstRect.x,
            dstRect.y,
            dstRect.w,
            dstRect.h,
            angle,
            center.x,
            center.y,
            flip,
        );
    };
}

export class SDLBridge {
    private module: EmscriptenModuleShape | null = null;
    private api: JulGameSdlApi | null = null;

    async init(
        canvas: HTMLCanvasElement,
        print: (text: string) => void,
        printErr: (text: string) => void,
    ): Promise<void> {
        this.module = (await loadSDLModule(canvas, print, printErr)) as EmscriptenModuleShape;
        const cwrap = this.module.cwrap;
        if (typeof cwrap !== "function") {
            throw new Error("Emscripten module missing cwrap (add EXPORTED_RUNTIME_METHODS)");
        }
        const cApi: JulGameSdlCApi = {
            glue_init: cwrap("glue_init", "number", ["number", "number"]) as JulGameSdlCApi["glue_init"],
            glue_render_square_frame: cwrap("glue_render_square_frame", null, []) as JulGameSdlCApi["glue_render_square_frame"],
            glue_poll_quit: cwrap("glue_poll_quit", "number", []) as JulGameSdlCApi["glue_poll_quit"],
            glue_SDL_GetTicks: cwrap("glue_SDL_GetTicks", "number", []) as JulGameSdlCApi["glue_SDL_GetTicks"],
            glue_get_renderer: cwrap("glue_get_renderer", "number", []) as JulGameSdlCApi["glue_get_renderer"],
            glue_SDL_RenderClear: cwrap("glue_SDL_RenderClear", null, []) as JulGameSdlCApi["glue_SDL_RenderClear"],
            glue_SDL_RenderPresent: cwrap("glue_SDL_RenderPresent", null, []) as JulGameSdlCApi["glue_SDL_RenderPresent"],
            glue_SDL_RenderSetLogicalSize: cwrap("glue_SDL_RenderSetLogicalSize", null, [
                "number",
                "number",
            ]) as JulGameSdlCApi["glue_SDL_RenderSetLogicalSize"],
            glue_SDL_SetRenderDrawBlendMode_BLEND: cwrap("glue_SDL_SetRenderDrawBlendMode_BLEND", null, []) as JulGameSdlCApi["glue_SDL_SetRenderDrawBlendMode_BLEND"],
            glue_SDL_SetRenderDrawColor: cwrap("glue_SDL_SetRenderDrawColor", null, [
                "number",
                "number",
                "number",
                "number",
            ]) as JulGameSdlCApi["glue_SDL_SetRenderDrawColor"],
            glue_SDL_RenderFillRectF: cwrap("glue_SDL_RenderFillRectF", null, [
                "number",
                "number",
                "number",
                "number",
            ]) as JulGameSdlCApi["glue_SDL_RenderFillRectF"],
            glue_IMG_Load: cwrap("glue_IMG_Load", "number", ["string"]) as JulGameSdlCApi["glue_IMG_Load"],
            glue_SDL_CreateTextureFromSurface: cwrap("glue_SDL_CreateTextureFromSurface", "number", [
                "number",
            ]) as JulGameSdlCApi["glue_SDL_CreateTextureFromSurface"],
            glue_SDL_FreeSurface: cwrap("glue_SDL_FreeSurface", null, ["number"]) as JulGameSdlCApi["glue_SDL_FreeSurface"],
            glue_SDL_GetError: cwrap("glue_SDL_GetError", "string", []) as JulGameSdlCApi["glue_SDL_GetError"],
            glue_SDL_ClearError: cwrap("glue_SDL_ClearError", null, []) as JulGameSdlCApi["glue_SDL_ClearError"],
            glue_surface_w: cwrap("glue_surface_w", "number", ["number"]) as JulGameSdlCApi["glue_surface_w"],
            glue_surface_h: cwrap("glue_surface_h", "number", ["number"]) as JulGameSdlCApi["glue_surface_h"],
            glue_SDL_SetTextureColorMod: cwrap("glue_SDL_SetTextureColorMod", null, [
                "number",
                "number",
                "number",
                "number",
            ]) as JulGameSdlCApi["glue_SDL_SetTextureColorMod"],
            glue_SDL_SetTextureAlphaMod: cwrap("glue_SDL_SetTextureAlphaMod", null, ["number", "number"]) as JulGameSdlCApi["glue_SDL_SetTextureAlphaMod"],
            glue_render_copy_ex: cwrap("glue_render_copy_ex", "number", [
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
            ]) as JulGameSdlCApi["glue_render_copy_ex"],
            glue_render_copy_ex_f: cwrap("glue_render_copy_ex_f", "number", [
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
                "number",
            ]) as JulGameSdlCApi["glue_render_copy_ex_f"],
        };

        const glue_SDL_FRect: JulGameSdlApi["glue_SDL_FRect"] = (x, y, w, h) => ({ x, y, w, h });
        const glue_SDL_Rect: JulGameSdlApi["glue_SDL_Rect"] = (x, y, w, h) => ({ x, y, w, h });
        const glue_SDL_Point: JulGameSdlApi["glue_SDL_Point"] = (x, y) => ({ x, y });
        const glue_SDL_FPoint: JulGameSdlApi["glue_SDL_FPoint"] = (x, y) => ({ x, y });

        const glue_SDL_RenderFillRectFWrapped = (a: unknown, b?: number, cArg?: number, d?: number): void => {
            if (typeof b === "number" && typeof cArg === "number" && typeof d === "number" && typeof a === "number") {
                cApi.glue_SDL_RenderFillRectF(a, b, cArg, d);
                return;
            }
            if (a !== null && typeof a === "object" && "x" in (a as object) && "w" in (a as object)) {
                const r = a as { x: number; y: number; w: number; h: number };
                cApi.glue_SDL_RenderFillRectF(r.x, r.y, r.w, r.h);
            }
        };

        this.api = {
            ...cApi,
            glue_SDL_FRect,
            glue_SDL_Rect,
            glue_SDL_Point,
            glue_SDL_FPoint,
            glue_SDL_RenderFillRectF: glue_SDL_RenderFillRectFWrapped as JulGameSdlApi["glue_SDL_RenderFillRectF"],
            glue_SDL_RenderCopyEx: wrapRenderCopyEx(cApi.glue_render_copy_ex),
            glue_SDL_RenderCopyExF: wrapRenderCopyExF(cApi.glue_render_copy_ex_f),
        };
    }

    getApi(): JulGameSdlApi {
        if (!this.api) {
            throw new Error("SDL bridge not initialized");
        }
        return this.api;
    }

    getModule(): EmscriptenModuleShape {
        if (!this.module) {
            throw new Error("SDL module is not initialized");
        }
        return this.module;
    }
}
