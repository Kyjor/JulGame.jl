import type { JulGameSdlApi } from "./SDLBridge";
import { SDL_SCANCODE_ENTRIES, SDL_SCANCODE_TABLE } from "./sdlScancodes";

type Cwrap = (
    ident: string,
    returnType: string | null,
    argTypes: string[],
) => (...args: unknown[]) => unknown;

type EmModule = {
    cwrap: Cwrap;
    HEAPU8?: Uint8Array;
};

export type SdlInputEvent = {
    type: number;
    button: { x: number; y: number; button: number };
    window: { event: number };
};

/** SDL event type / button constants used by transpiled Input.ts */
export const SDL_INPUT_CONSTANTS = {
    SDL_QUIT: 0x100,
    SDL_WINDOWEVENT: 0x200,
    SDL_KEYDOWN: 0x300,
    SDL_KEYUP: 0x301,
    SDL_MOUSEMOTION: 0x400,
    SDL_MOUSEBUTTONDOWN: 0x401,
    SDL_MOUSEBUTTONUP: 0x402,
    SDL_BUTTON_LEFT: 1,
    SDL_BUTTON_MIDDLE: 2,
    SDL_BUTTON_RIGHT: 3,
    SDL_INIT_JOYSTICK: 0x00000200,
    SDL_SCANCODE_F3: 60,
};

type InputCApi = {
    glue_input_poll_event: () => number;
    glue_input_event_type: () => number;
    glue_input_event_button_x: () => number;
    glue_input_event_button_y: () => number;
    glue_input_event_button_button: () => number;
    glue_input_event_window_event: () => number;
    glue_input_get_mouse_x: () => number;
    glue_input_get_mouse_y: () => number;
    glue_input_get_keyboard_state: () => number;
    glue_input_get_num_scancodes: () => number;
};

function cwrapNumberFn(
    cwrap: Cwrap,
    name: string,
    argTypes: string[] = [],
): ((...args: number[]) => number) | null {
    const fn = cwrap(name, "number", argTypes) as ((...args: number[]) => number) | undefined;
    return typeof fn === "function" ? fn : null;
}

function moduleHeapU8(mod: EmModule): Uint8Array | null {
    if (mod.HEAPU8 instanceof Uint8Array) {
        return mod.HEAPU8;
    }
    const wasmMemory = (mod as { wasmMemory?: { buffer: ArrayBuffer } }).wasmMemory;
    if (wasmMemory?.buffer) {
        return new Uint8Array(wasmMemory.buffer);
    }
    return null;
}

function readKeyboardStateFromHeap(mod: EmModule, ptr: number, numKeys: number): Uint8Array | null {
    const heap = moduleHeapU8(mod);
    if (!heap || ptr <= 0 || numKeys <= 0) {
        return null;
    }
    return heap.subarray(ptr, ptr + numKeys);
}

/** Attach SDL input APIs expected by `_generated/src/engine/Input/Input.ts`. */
export function attachSdlInputGlue(
    api: JulGameSdlApi,
    mod: EmModule,
): JulGameSdlApi {
    const cwrap = mod.cwrap;
    const c: InputCApi = {
        glue_input_poll_event: cwrap("glue_input_poll_event", "number", []) as InputCApi["glue_input_poll_event"],
        glue_input_event_type: cwrap("glue_input_event_type", "number", []) as InputCApi["glue_input_event_type"],
        glue_input_event_button_x: cwrap("glue_input_event_button_x", "number", []) as InputCApi["glue_input_event_button_x"],
        glue_input_event_button_y: cwrap("glue_input_event_button_y", "number", []) as InputCApi["glue_input_event_button_y"],
        glue_input_event_button_button: cwrap("glue_input_event_button_button", "number", []) as InputCApi["glue_input_event_button_button"],
        glue_input_event_window_event: cwrap("glue_input_event_window_event", "number", []) as InputCApi["glue_input_event_window_event"],
        glue_input_get_mouse_x: cwrap("glue_input_get_mouse_x", "number", []) as InputCApi["glue_input_get_mouse_x"],
        glue_input_get_mouse_y: cwrap("glue_input_get_mouse_y", "number", []) as InputCApi["glue_input_get_mouse_y"],
        glue_input_get_keyboard_state: cwrap("glue_input_get_keyboard_state", "number", []) as InputCApi["glue_input_get_keyboard_state"],
        glue_input_get_num_scancodes: cwrap("glue_input_get_num_scancodes", "number", []) as InputCApi["glue_input_get_num_scancodes"],
    };

    const initSubsystem = cwrapNumberFn(cwrap, "glue_SDL_Init_subsystem", ["number"]);
    const numJoysticks = cwrapNumberFn(cwrap, "glue_SDL_NumJoysticks", []);
    const keyDown = cwrapNumberFn(cwrap, "glue_input_key_down", ["number"]);

    let keyboardView: Uint8Array = new Uint8Array(0);

    const refreshKeyboardView = (): Uint8Array => {
        const len = c.glue_input_get_num_scancodes();
        if (len <= 0) {
            return keyboardView;
        }
        if (keyboardView.length !== len) {
            keyboardView = new Uint8Array(len);
        }
        if (keyDown) {
            for (let i = 0; i < len; i++) {
                keyboardView[i] = keyDown(i);
            }
            return keyboardView;
        }
        const ptr = c.glue_input_get_keyboard_state();
        const fromHeap = readKeyboardStateFromHeap(mod, ptr, len);
        if (fromHeap) {
            keyboardView.set(fromHeap);
        }
        return keyboardView;
    };

    const fillEvent = (evt: SdlInputEvent): void => {
        evt.type = c.glue_input_event_type();
        evt.button = {
            x: c.glue_input_event_button_x(),
            y: c.glue_input_event_button_y(),
            button: c.glue_input_event_button_button(),
        };
        evt.window = { event: c.glue_input_event_window_event() };
    };

    const extended = api as JulGameSdlApi & Record<string, unknown>;

    Object.assign(extended, SDL_INPUT_CONSTANTS, {
        SDL_SCANCODE_ENTRIES,
        glue_SDL_Scancode: SDL_SCANCODE_TABLE,
        glue_SDL_Event: (): SdlInputEvent => ({
            type: 0,
            button: { x: 0, y: 0, button: 0 },
            window: { event: 0 },
        }),
        glue_SDL_PollEvent: (evt: SdlInputEvent): number => {
            const ok = c.glue_input_poll_event();
            if (!ok) return 0;
            fillEvent(evt);
            return 1;
        },
        glue_SDL_GetMouseState: (x: number[], y: number[]): void => {
            x[0] = c.glue_input_get_mouse_x();
            y[0] = c.glue_input_get_mouse_y();
        },
        glue_SDL_GetWindowSize: (_window: number, w: number[], h: number[]): void => {
            const root = globalThis as {
                JulGame?: { MAIN?: { windowManager?: { windowSize?: { x: number; y: number } } } };
            };
            const size = root.JulGame?.MAIN?.windowManager?.windowSize ?? { x: 800, y: 600 };
            w[0] = size.x;
            h[0] = size.y;
        },
        glue_SDL_GetKeyboardState: (_unused: null): Uint8Array => refreshKeyboardView(),
        glue_SDL_Init: (flags: number): number => {
            if (initSubsystem) return initSubsystem(flags);
            // Older julgame.js builds lack this export; glue_init already inits SDL video.
            return 0;
        },
        glue_SDL_NumJoysticks: (): number => numJoysticks?.() ?? 0,
        glue_SDL_JoystickOpen: (_index: number): null => null,
        glue_SDL_JoystickName: (_joy: unknown): number => 0,
        glue_SDL_JoystickNumAxes: (_joy: unknown): number => 0,
        glue_SDL_JoystickNumButtons: (_joy: unknown): number => 0,
        glue_SDL_JoystickNumHats: (_joy: unknown): number => 0,
    });

    return extended;
}
