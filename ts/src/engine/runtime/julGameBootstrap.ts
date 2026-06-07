import type { JulGameSdlApi } from "../../platform/sdl-wasm/SDLBridge";
import { Camera, cameraPixelsPerWorldUnit, cameraUpdate } from "../../../_generated/src/engine/Camera/Camera";
import { force_frame_update } from "../../../_generated/src/engine/Component/Animator";
import {
    Component_add_collision_event,
    Component_check_collisions,
} from "../../../_generated/src/engine/Component/Collider";
import { add_velocity, Component_update as rigidbodyUpdate } from "../../../_generated/src/engine/Component/Rigidbody";
import { Component_flip } from "../../../_generated/src/engine/Component/Sprite";
import {
    Component_load_sound,
    Component_toggle_sound,
    InternalSoundSource,
} from "../../../_generated/src/engine/Component/SoundSource";
import { Entity, JulGame_add_script, JulGame_add_sprite, JulGame_update } from "../../../_generated/src/engine/Entity";
import { Scene } from "../../../_generated/src/engine/Scene";
import { installCoroutineGlobals } from "./coroutineRuntime";
import { installTranspiledInput } from "./inputBootstrap";
import { initializeScript, updateScript } from "./scriptRegistry";
import { installStrippedInput } from "./StrippedInput";
import { wireSceneApi } from "./scriptLoader";

/**
 * SDL / wasm entry: attach `JulGame`, `JulGameSdl`, `MAIN`, and `Renderer` expected by `_generated` modules.
 * Call after `JulGameSdl` c API is ready and before loading scenes or running frames.
 */
export type BootstrapOptions = {
    basePath?: string;
    gravity?: number;
};

export function bootstrapJulGameSdl(
    api: JulGameSdlApi,
    canvasWidth: number,
    canvasHeight: number,
    _canvas: HTMLCanvasElement,
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
    jg.BasePath = opts.basePath ?? "/game";
    jg.GRAVITY = opts.gravity ?? 9.81;
    jg.PIXELS_PER_UNIT = 64;
    jg.IMAGE_CACHE = [];
    jg.AUDIO_CACHE = [];
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

    jg.WindowManagerModule = {
        get_logical_size: () => ({ x: canvasWidth, y: canvasHeight }),
        set_logical_size: (_w: number, _h: number) => {
            /* No WindowManager in stripped build */
        },
        handle_window_event: (_event: number) => {
            /* No-op in stripped WASM runtime */
        },
    };

    jg.Renderer = api.glue_get_renderer();

    const scene = new Scene();
    scene.name = "stripped";

    root.MAIN = {
        scene,
        windowManager: {
            window: 0,
            isWindowFocused: true,
            windowSize: { x: canvasWidth, y: canvasHeight },
        },
        errorLogger: {},
        isGameModeRunningInEditor: false,
    };
    jg.MAIN = root.MAIN;
    installTranspiledInput(jg, root.MAIN);
    installCoroutineGlobals(jg);
    wireSceneApi(jg);
    jg.Component = {
        add_collision_event: Component_add_collision_event,
        check_collisions: Component_check_collisions,
        toggle_sound: Component_toggle_sound,
        load_sound: Component_load_sound,
        flip: Component_flip,
    };
    jg.RigidbodyModule = { add_velocity, Component_update: rigidbodyUpdate };
    jg.AnimatorModule = { force_frame_update };
    jg.Math = {
        Vector2f: (x: number, y: number) => ({ x, y }),
        Vector3f: (x: number, y: number, z: number) => ({ x, y, z }),
    };
    jg.SoundSourceModule = {
        InternalSoundSource: (...args: ConstructorParameters<typeof InternalSoundSource>) =>
            new InternalSoundSource(...args),
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
