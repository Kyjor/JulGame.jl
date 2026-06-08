import type { JulGameSdlApi } from "../../platform/sdl-wasm/SDLBridge";
import { Camera, cameraPixelsPerWorldUnit, cameraUpdate } from "../../../_generated/src/engine/Camera/Camera";
import { force_frame_update } from "../../../_generated/src/engine/Component/Animator";
import {
    Component_add_collision_event,
    Component_check_collisions,
} from "../../../_generated/src/engine/Component/Collider";
import { add_velocity, Component_get_velocity, Component_update as rigidbodyUpdate } from "../../../_generated/src/engine/Component/Rigidbody";
import { Component_flip } from "../../../_generated/src/engine/Component/Sprite";
import {
    Component_load_sound,
    Component_toggle_sound,
    InternalSoundSource,
} from "../../../_generated/src/engine/Component/SoundSource";
import { Entity, JulGame_add_script, JulGame_add_sprite, JulGame_update } from "../../../_generated/src/engine/Entity";
import { Scene } from "../../../_generated/src/engine/Scene";
import { installCoroutineGlobals } from "./coroutineRuntime";
import { initializeScript, updateScript } from "./scriptRegistry";
import { installStrippedInput } from "./StrippedInput";
import {
    UI_add_click_event,
    UI_add_hover_enter_event,
    UI_add_hover_exit_event,
    UI_align_to_anchor,
    UI_set_color,
} from "../../../_generated/src/engine/UI/UIElement";
import { wireSceneApi } from "./scriptLoader";

/**
 * SDL / wasm entry: attach `JulGame`, `JulGameSdl`, `MAIN`, and `Renderer` expected by `_generated` modules.
 * Call after `JulGameSdl` c API is ready and before loading scenes or running frames.
 */
export type BootstrapOptions = {
    basePath?: string;
    gravity?: number;
    /** Default sprite PPU when scene sprites use `-1` or omit the field (Julia `PIXELS_PER_UNIT`). */
    pixelsPerUnit?: number;
};

export function bootstrapJulGameSdl(
    api: JulGameSdlApi,
    canvasWidth: number,
    canvasHeight: number,
    canvas: HTMLCanvasElement,
    opts: BootstrapOptions = {},
): void {
    const root = globalThis as unknown as {
        JulGameSdl: JulGameSdlApi;
        JulGame: Record<string, unknown>;
        MAIN: Record<string, unknown>;
    };

    root.JulGameSdl = api;
    const jg = (root.JulGame ??= {}) as Record<string, unknown>;

    jg.generate_uuid = () => {
        if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
            return crypto.randomUUID();
        }
        return `id-${Math.random().toString(36).slice(2, 11)}`;
    };
    jg.add_script = JulGame_add_script;
    jg.add_sprite = JulGame_add_sprite;
    jg.update = (obj: unknown, deltaTime = 0) => {
        if (obj && typeof obj === "object" && "scripts" in obj) {
            JulGame_update(obj as Entity, deltaTime);
        } else {
            updateScript(obj, deltaTime);
        }
    };
    jg.initialize = (script: unknown) => {
        initializeScript(script);
    };
    jg.updateScript = (script: unknown, deltaTime: number) => {
        updateScript(script, deltaTime);
    };
    jg.pixels_per_world_unit = cameraPixelsPerWorldUnit;
    jg.CameraModule = { update: cameraUpdate };
    jg.IS_EDITOR = false;
    jg.IS_WEB = true;
    jg.IS_DEBUG = false;
    jg.maybe_enable_latency_profiling_from_env = () => {
        /* stripped WASM: latency profiling not wired */
    };
    jg.BasePath = opts.basePath ?? "/game";
    jg.GRAVITY = opts.gravity ?? 9.81;
    jg.PIXELS_PER_UNIT = opts.pixelsPerUnit ?? 16;
    jg.IMAGE_CACHE = {};
    jg.FONT_CACHE = {};
    jg.TEXTURE_CACHE = {};
    jg.AUDIO_CACHE = {};
    jg.Coroutines = [];
    jg.FrameCount = 0;
    jg.DELTA_TIME = 0;
    jg.EditorGameViewPosition = { x: 0, y: 0 };
    jg.EditorGameViewSize = { x: canvasWidth, y: canvasHeight };
    jg.ErrorLoggingModule = {
        log_error: (_logger: unknown, msg: string, _ex?: unknown) => {
            console.error(msg);
        },
    };
    jg.get_comma_separated_path = (p: string) =>
        String(p)
            .replace(/\\/g, "/")
            .split("/")
            .filter(Boolean)
            .join(",");

    let logicalSize = { x: canvasWidth, y: canvasHeight };
    jg.WindowManagerModule = {
        get_logical_size: () => logicalSize,
        set_logical_size: (w: number, h: number) => {
            logicalSize = { x: w, y: h };
        },
        handle_window_event: (_event: number) => {
            /* No-op in stripped WASM runtime */
        },
    };

    jg.Renderer = api.glue_get_renderer();

    const scene = new Scene();
    scene.name = "stripped";

    jg.MainLoopModule = {
        create_new_canvas: () => {
            const canvas = {
                type: "Canvas" as const,
                id: (jg.generate_uuid as () => string)(),
                name: "New Canvas",
                isActive: false,
                persistentBetweenScenes: false,
                children: [] as unknown[],
                layer: 0,
            };
            scene.uiElements.push(canvas as never);
            return canvas;
        },
    };

    root.MAIN = {
        scene,
        windowManager: {
            window: 0,
            isWindowFocused: true,
            windowSize: { x: canvasWidth, y: canvasHeight },
        },
        errorLogger: {},
        isGameModeRunningInEditor: false,
        optimizeSpriteRendering: false,
    };
    jg.MAIN = root.MAIN;
    // DOM input — avoids transpiled Input.ts SDL_PollEvent + joystick init (WASM OOB on mouse/audio).
    installStrippedInput(jg, root.MAIN, canvas);
    installCoroutineGlobals(jg);
    wireSceneApi(jg);
    jg.Component = {
        add_collision_event: Component_add_collision_event,
        check_collisions: Component_check_collisions,
        toggle_sound: Component_toggle_sound,
        load_sound: Component_load_sound,
        flip: Component_flip,
        unload_sound: (_source: unknown) => {
            /* stripped WASM: no-op until sound unload is wired */
        },
    };
    jg.RigidbodyModule = { add_velocity, Component_update: rigidbodyUpdate, Component_get_velocity };
    jg.AnimatorModule = { force_frame_update };
    jg.TransformModule = {
        Transform: (v: { x: number; y: number; z: number }) => ({
            position: v,
            scale: { x: 1, y: 1, z: 1 },
        }),
    };
    jg.change_scene = (sceneFileName: string) => {
        console.warn(`change_scene("${sceneFileName}") — stripped scene runtime not installed yet`);
    };
    jg.set_batched_layer_offset = (_layer: number, _x: number, _y: number) => {
        /* stripped WASM: StaticSpriteBatcher not wired */
    };
    jg.Math = {
        Vector2f: (x: number, y: number) => ({ x, y }),
        Vector3f: (x: number, y: number, z: number) => ({ x, y, z }),
    };
    jg.SoundSourceModule = {
        InternalSoundSource: (...args: ConstructorParameters<typeof InternalSoundSource>) =>
            new InternalSoundSource(...args),
    };
    jg.UserGlobals = jg.UserGlobals ?? { Module: {} };
    jg.UI = {
        align_to_anchor: UI_align_to_anchor,
        set_color: (
            el: Parameters<typeof UI_set_color>[0],
            rOrOpts?: number | { r?: number; g?: number; b?: number; a?: number },
            g?: number,
            b?: number,
            a?: number,
        ) => {
            if (typeof rOrOpts === "number" && g === undefined) {
                UI_set_color(el, 255, 255, 255, rOrOpts);
            } else if (typeof rOrOpts === "object" && rOrOpts !== null) {
                UI_set_color(el, rOrOpts.r, rOrOpts.g, rOrOpts.b, rOrOpts.a);
            } else {
                UI_set_color(el, rOrOpts as number | undefined, g, b, a);
            }
        },
        add_click_event: UI_add_click_event,
        add_hover_enter_event: UI_add_hover_enter_event,
        add_hover_exit_event: UI_add_hover_exit_event,
    };
    jg.ImmediateUIModule = {
        immediate_text: (
            _id: string,
            text: string,
            _opts?: Record<string, unknown>,
        ) => ({
            text: String(text),
            isActive: true,
        }),
        INFINITE_LIFETIME: -1,
    };
}

/** DOM input fallback for `?backend=web` (no SDL). */
export function bootstrapWebInput(canvas: HTMLCanvasElement): void {
    const root = globalThis as unknown as {
        JulGame: Record<string, unknown>;
        MAIN: Record<string, unknown>;
    };
    const jg = (root.JulGame ??= {});
    const main = (root.MAIN ??= {});
    jg.MAIN = main;
    installStrippedInput(jg, main, canvas);
}

export function attachDefaultCamera(scene: Scene, width: number, height: number): Camera {
    const cam = new Camera(
        { x: width, y: height },
        { x: 0, y: 0, z: 0 },
        { x: 0, y: 0 },
        null,
    );
    scene.camera = cam;
    return cam;
}
