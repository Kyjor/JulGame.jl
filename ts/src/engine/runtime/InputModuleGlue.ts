import { poll_input, type TranspiledInput } from "./transpiledInput";

type MainShape = { input: TranspiledInput | null };

function mainInput(): TranspiledInput | null {
    return (globalThis as { MAIN?: MainShape }).MAIN?.input ?? null;
}

function resolveInput(inputOrName?: TranspiledInput | string): TranspiledInput | null {
    if (inputOrName === undefined || typeof inputOrName === "string") {
        return mainInput();
    }
    return inputOrName;
}

function resolveName(inputOrName: TranspiledInput | string, name?: string): string {
    return (name ?? (inputOrName as string)).toUpperCase();
}

/** Hand-written mirror of `src/engine/Input/api.jl` for transpiled Input state. */
export const InputModule = {
    poll_input,

    get_button_held_down(inputOrName: TranspiledInput | string, button?: string): boolean {
        const input = resolveInput(inputOrName);
        const name = resolveName(inputOrName, button);
        return input?.buttonsHeldDown.includes(name) ?? false;
    },

    get_button_pressed(inputOrName: TranspiledInput | string, button?: string): boolean {
        const input = resolveInput(inputOrName);
        const name = resolveName(inputOrName, button);
        return input?.buttonsPressedDown.includes(name) ?? false;
    },

    get_button_released(inputOrName: TranspiledInput | string, button?: string): boolean {
        const input = resolveInput(inputOrName);
        const name = resolveName(inputOrName, button);
        return input?.buttonsReleased.includes(name) ?? false;
    },

    get_mouse_button(inputOrName: TranspiledInput | number, button?: number): boolean {
        const input = typeof inputOrName === "number" ? mainInput() : resolveInput(inputOrName);
        const btn = button ?? (inputOrName as number);
        return input?.mouseButtonsHeldDown.includes(btn) ?? false;
    },

    get_mouse_button_pressed(inputOrName: TranspiledInput | number, button?: number): boolean {
        const input = typeof inputOrName === "number" ? mainInput() : resolveInput(inputOrName);
        const btn = button ?? (inputOrName as number);
        return input?.mouseButtonsPressedDown.includes(btn) ?? false;
    },

    get_mouse_button_released(inputOrName: TranspiledInput | number, button?: number): boolean {
        const input = typeof inputOrName === "number" ? mainInput() : resolveInput(inputOrName);
        const btn = button ?? (inputOrName as number);
        return input?.mouseButtonsReleased.includes(btn) ?? false;
    },

    get_mouse_position(input?: TranspiledInput): { x: number; y: number } {
        const state = input ?? mainInput();
        return state?.mousePosition ?? { x: 0, y: 0 };
    },

    get_mouse_position_in_world_space(input?: TranspiledInput): { x: number; y: number } {
        const state = input ?? mainInput();
        return state?.mousePositionWorld ?? { x: 0, y: 0 };
    },
};
