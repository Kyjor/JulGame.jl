/** Minimal input state + DOM listeners for the stripped SDL/web runtime. */
/** Fallback only — SDL path uses transpiled `_generated/Input/Input.ts` via `inputBootstrap.ts`. */

import {
    dispatchSceneMouseUpClicks,
    hitTestScenePressTarget,
    updateSceneEntityHover,
    type SceneShape,
} from "./scenePointerInput";
import {
    canvasPixelsToLogicalUiSpace,
    updateUiPointerHover,
    type UiHoverTarget,
} from "./uiRender";

export type StrippedInputState = {
    buttonsPressedDown: string[];
    buttonsHeldDown: string[];
    buttonsReleased: string[];
    mouseButtonsPressedDown: number[];
    mouseButtonsHeldDown: number[];
    mouseButtonsReleased: number[];
    mousePosition: { x: number; y: number };
    mousePositionWorld: { x: number; y: number };
    mousePositionEditorGameWindowOffset: { x: number; y: number };
    /** Set when the pointer moves; cleared at end of each game frame (Julia `MAIN.input.didMouseMotionOccur`). */
    didMouseMotionOccur: boolean;
    /** Wheel delta in pixels this frame (positive = scroll down). Reset each poll. */
    mouseScrollY: number;
    quit: boolean;
    debug: boolean;
    main: unknown;
};

type MainShape = { input: StrippedInputState | null };

const DOM_ARROW: Record<string, string> = {
    ArrowLeft: "LEFT",
    ArrowRight: "RIGHT",
    ArrowUp: "UP",
    ArrowDown: "DOWN",
};

/** Map browser keys to SDL-style scan names used by generated JulGame code. */
export function domKeyToButton(code: string, key: string): string {
    const arrow = DOM_ARROW[code];
    if (arrow) return arrow;
    if (code.startsWith("Key") && code.length === 4) {
        return code.slice(3).toUpperCase();
    }
    if (code.startsWith("Digit") && code.length === 6) {
        return code.slice(5);
    }
    if (code === "Space") return "SPACE";
    if (code === "Escape") return "ESCAPE";
    if (code === "Enter") return "RETURN";
    if (code === "ShiftLeft" || code === "ShiftRight") return "LSHIFT";
    if (code === "ControlLeft" || code === "ControlRight") return "LCTRL";
    if (key.length === 1) return key.toUpperCase();
    return code.replace(/^(Key|Digit)/, "").toUpperCase();
}

/** SDL mouse button id (1 = left, 2 = middle, 3 = right). */
function domButtonToSdl(button: number): number {
    if (button === 0) return 1;
    if (button === 1) return 3;
    if (button === 2) return 2;
    return button + 1;
}

export function createStrippedInput(): StrippedInputState {
    return {
        buttonsPressedDown: [],
        buttonsHeldDown: [],
        buttonsReleased: [],
        mouseButtonsPressedDown: [],
        mouseButtonsHeldDown: [],
        mouseButtonsReleased: [],
        mousePosition: { x: 0, y: 0 },
        mousePositionWorld: { x: 0, y: 0 },
        mousePositionEditorGameWindowOffset: { x: 0, y: 0 },
        didMouseMotionOccur: false,
        mouseScrollY: 0,
        quit: false,
        debug: false,
        main: null,
    };
}

function syncHeldArrays(input: StrippedInputState, heldKeys: Set<string>, heldMouse: Set<number>): void {
    input.buttonsHeldDown = [...heldKeys];
    input.mouseButtonsHeldDown = [...heldMouse];
}

/** Per-frame: flush edge-triggered key/mouse transitions into Julia-compatible arrays. */
export function pollStrippedInput(
    input: StrippedInputState,
    heldKeys: Set<string>,
    heldMouse: Set<number>,
    pressedKeys: Set<string>,
    releasedKeys: Set<string>,
    pressedMouse: Set<number>,
    releasedMouse: Set<number>,
): void {
    input.buttonsPressedDown = [...pressedKeys];
    input.buttonsReleased = [...releasedKeys];
    input.mouseButtonsPressedDown = [...pressedMouse];
    input.mouseButtonsReleased = [...releasedMouse];
    pressedKeys.clear();
    releasedKeys.clear();
    pressedMouse.clear();
    releasedMouse.clear();
    syncHeldArrays(input, heldKeys, heldMouse);
}

function canvasMousePosition(canvas: HTMLCanvasElement, clientX: number, clientY: number): { x: number; y: number } {
    const rect = canvas.getBoundingClientRect();
    const sx = canvas.width / Math.max(rect.width, 1);
    const sy = canvas.height / Math.max(rect.height, 1);
    return {
        x: (clientX - rect.left) * sx,
        y: (clientY - rect.top) * sy,
    };
}

function isPointerInsideCanvas(canvas: HTMLCanvasElement, clientX: number, clientY: number): boolean {
    const rect = canvas.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) {
        return true;
    }
    const pad = 2;
    return (
        clientX >= rect.left - pad &&
        clientX <= rect.right + pad &&
        clientY >= rect.top - pad &&
        clientY <= rect.bottom + pad
    );
}

export type DomInputBinding = {
    detach: () => void;
    heldKeys: Set<string>;
    heldMouse: Set<number>;
    pressedKeys: Set<string>;
    releasedKeys: Set<string>;
    pressedMouse: Set<number>;
    releasedMouse: Set<number>;
    pendingWheelY: number;
};

/** Attach keyboard/pointer listeners for stripped SDL/web runtime (itch iframe-safe). */
export function attachDomInput(canvas: HTMLCanvasElement): DomInputBinding {
    canvas.tabIndex = 0;
    canvas.style.outline = "none";
    canvas.style.touchAction = "none";

    const heldKeys = new Set<string>();
    const heldMouse = new Set<number>();
    const pressedKeys = new Set<string>();
    const releasedKeys = new Set<string>();
    const pressedMouse = new Set<number>();
    const releasedMouse = new Set<number>();
    let pendingWheelY = 0;
    let lastUiHover: UiHoverTarget | null = null;
    let pointerPressTarget: unknown | null = null;

    const focusCanvas = (): void => {
        canvas.focus({ preventScroll: true });
    };

    const onKeyDown = (e: KeyboardEvent): void => {
        const name = domKeyToButton(e.code, e.key);
        if (!heldKeys.has(name)) {
            pressedKeys.add(name);
        }
        heldKeys.add(name);
        if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"].includes(e.code)) {
            e.preventDefault();
        }
    };

    const onKeyUp = (e: KeyboardEvent): void => {
        const name = domKeyToButton(e.code, e.key);
        heldKeys.delete(name);
        releasedKeys.add(name);
    };

    const uiPointerPos = (clientX: number, clientY: number): { x: number; y: number } => {
        const canvasPos = canvasMousePosition(canvas, clientX, clientY);
        return canvasPixelsToLogicalUiSpace(canvas.width, canvas.height, canvasPos.x, canvasPos.y);
    };

    const applyPointerMove = (clientX: number, clientY: number): void => {
        const root = globalThis as { MAIN?: MainShape };
        const input = root.MAIN?.input;
        if (!input) return;
        const uiPos = uiPointerPos(clientX, clientY);
        input.mousePosition = uiPos;
        input.didMouseMotionOccur = true;
        const scene = root.MAIN?.scene as SceneShape | undefined;
        if (scene) {
            lastUiHover = updateUiPointerHover(scene.uiElements ?? [], uiPos.x, uiPos.y, lastUiHover);
            updateSceneEntityHover(scene, uiPos.x, uiPos.y);
        }
    };

    const onPointerMove = (e: PointerEvent): void => {
        if (!isPointerInsideCanvas(canvas, e.clientX, e.clientY)) {
            return;
        }
        applyPointerMove(e.clientX, e.clientY);
    };

    const onPointerDown = (e: PointerEvent): void => {
        if (!isPointerInsideCanvas(canvas, e.clientX, e.clientY)) {
            return;
        }
        e.preventDefault();
        focusCanvas();
        try {
            canvas.setPointerCapture(e.pointerId);
        } catch {
            // ignore — some embed contexts reject capture
        }

        const btn = domButtonToSdl(e.button);
        if (!heldMouse.has(btn)) {
            pressedMouse.add(btn);
        }
        heldMouse.add(btn);
        applyPointerMove(e.clientX, e.clientY);

        if (e.button !== 0) {
            return;
        }
        const root = globalThis as { MAIN?: MainShape };
        const scene = root.MAIN?.scene as SceneShape | undefined;
        if (scene) {
            const uiPos = uiPointerPos(e.clientX, e.clientY);
            pointerPressTarget = hitTestScenePressTarget(scene, uiPos.x, uiPos.y);
        }
    };

    const onPointerUp = (e: PointerEvent): void => {
        const btn = domButtonToSdl(e.button);
        heldMouse.delete(btn);
        releasedMouse.add(btn);
        applyPointerMove(e.clientX, e.clientY);

        if (e.button !== 0) {
            return;
        }
        const root = globalThis as { MAIN?: MainShape };
        const scene = root.MAIN?.scene as SceneShape | undefined;
        const pressTarget = pointerPressTarget;
        pointerPressTarget = null;
        if (scene) {
            const uiPos = uiPointerPos(e.clientX, e.clientY);
            dispatchSceneMouseUpClicks(scene, uiPos.x, uiPos.y, pressTarget);
        }
        try {
            if (canvas.hasPointerCapture(e.pointerId)) {
                canvas.releasePointerCapture(e.pointerId);
            }
        } catch {
            // ignore
        }
    };

    const onWheel = (e: WheelEvent): void => {
        if (!isPointerInsideCanvas(canvas, e.clientX, e.clientY)) {
            return;
        }
        let dy = e.deltaY;
        if (e.deltaMode === WheelEvent.DOM_DELTA_LINE) {
            dy *= 16;
        } else if (e.deltaMode === WheelEvent.DOM_DELTA_PAGE) {
            dy *= canvas.height;
        }
        pendingWheelY += dy;
        e.preventDefault();
    };

    const onBlur = (): void => {
        for (const k of heldKeys) {
            releasedKeys.add(k);
        }
        heldKeys.clear();
        for (const b of heldMouse) {
            releasedMouse.add(b);
        }
        heldMouse.clear();
        pointerPressTarget = null;
        if (lastUiHover) {
            for (const fn of lastUiHover.hoverExitEvents) {
                fn();
            }
            lastUiHover = null;
        }
    };

    const pointerOpts: AddEventListenerOptions = { capture: true, passive: false };
    window.addEventListener("pointerdown", onPointerDown, pointerOpts);
    window.addEventListener("pointerup", onPointerUp, pointerOpts);
    window.addEventListener("pointermove", onPointerMove, pointerOpts);
    window.addEventListener("pointercancel", onPointerUp, pointerOpts);
    document.addEventListener("keydown", onKeyDown);
    document.addEventListener("keyup", onKeyUp);
    window.addEventListener("blur", onBlur);
    canvas.addEventListener("click", focusCanvas);
    canvas.addEventListener("wheel", onWheel, { passive: false });

    return {
        heldKeys,
        heldMouse,
        pressedKeys,
        releasedKeys,
        pressedMouse,
        releasedMouse,
        get pendingWheelY() {
            return pendingWheelY;
        },
        set pendingWheelY(value: number) {
            pendingWheelY = value;
        },
        detach: () => {
            window.removeEventListener("pointerdown", onPointerDown, pointerOpts);
            window.removeEventListener("pointerup", onPointerUp, pointerOpts);
            window.removeEventListener("pointermove", onPointerMove, pointerOpts);
            window.removeEventListener("pointercancel", onPointerUp, pointerOpts);
            document.removeEventListener("keydown", onKeyDown);
            document.removeEventListener("keyup", onKeyUp);
            window.removeEventListener("blur", onBlur);
            canvas.removeEventListener("click", focusCanvas);
            canvas.removeEventListener("wheel", onWheel);
        },
    };
}

function getMainInput(inputOrButton?: StrippedInputState | string): StrippedInputState | null {
    const root = globalThis as { MAIN?: MainShape };
    if (typeof inputOrButton === "string" || inputOrButton === undefined) {
        return root.MAIN?.input ?? null;
    }
    return inputOrButton;
}

/** Mirrors `src/engine/Input/api.jl` for generated game code. */
export const StrippedInputModule = {
    poll_input(input: StrippedInputState): void {
        const binding = (input as StrippedInputState & { __dom?: DomInputBinding }).__dom;
        if (!binding) return;
        pollStrippedInput(
            input,
            binding.heldKeys,
            binding.heldMouse,
            binding.pressedKeys,
            binding.releasedKeys,
            binding.pressedMouse,
            binding.releasedMouse,
        );
        input.mouseScrollY = binding.pendingWheelY;
        binding.pendingWheelY = 0;
    },

    get_mouse_scroll(input?: StrippedInputState): number {
        const state = input ?? getMainInput();
        return state?.mouseScrollY ?? 0;
    },

    get_button_held_down(inputOrButton: StrippedInputState | string, button?: string): boolean {
        const input = button === undefined ? getMainInput() : getMainInput(inputOrButton as StrippedInputState);
        const name = (button ?? (inputOrButton as string)).toUpperCase();
        return input?.buttonsHeldDown.includes(name) ?? false;
    },

    get_button_pressed(inputOrButton: StrippedInputState | string, button?: string): boolean {
        const input = button === undefined ? getMainInput() : getMainInput(inputOrButton as StrippedInputState);
        const name = (button ?? (inputOrButton as string)).toUpperCase();
        return input?.buttonsPressedDown.includes(name) ?? false;
    },

    get_button_released(inputOrButton: StrippedInputState | string, button?: string): boolean {
        const input = button === undefined ? getMainInput() : getMainInput(inputOrButton as StrippedInputState);
        const name = (button ?? (inputOrButton as string)).toUpperCase();
        return input?.buttonsReleased.includes(name) ?? false;
    },

    get_mouse_button(inputOrButton: StrippedInputState | number, button?: number): boolean {
        const input = button === undefined ? getMainInput() : getMainInput(inputOrButton as StrippedInputState);
        const btn = button ?? (inputOrButton as number);
        return input?.mouseButtonsHeldDown.includes(btn) ?? false;
    },

    get_mouse_button_pressed(inputOrButton: StrippedInputState | number, button?: number): boolean {
        const input = button === undefined ? getMainInput() : getMainInput(inputOrButton as StrippedInputState);
        const btn = button ?? (inputOrButton as number);
        return input?.mouseButtonsPressedDown.includes(btn) ?? false;
    },

    get_mouse_button_released(inputOrButton: StrippedInputState | number, button?: number): boolean {
        const input = button === undefined ? getMainInput() : getMainInput(inputOrButton as StrippedInputState);
        const btn = button ?? (inputOrButton as number);
        return input?.mouseButtonsReleased.includes(btn) ?? false;
    },

    get_mouse_position(input?: StrippedInputState): { x: number; y: number } {
        const state = input ?? getMainInput();
        return state?.mousePosition ?? { x: 0, y: 0 };
    },

    get_mouse_position_in_world_space(input?: StrippedInputState): { x: number; y: number } {
        const state = input ?? getMainInput();
        return state?.mousePositionWorld ?? { x: 0, y: 0 };
    },

    simulate_mouse_click(_inputOrX: StrippedInputState | number, y?: number): void {
        const root = globalThis as { MAIN?: { scene?: SceneShape; input?: StrippedInputState } };
        const scene = root.MAIN?.scene;
        if (!scene) {
            return;
        }
        let x: number;
        if (typeof _inputOrX === "number") {
            x = _inputOrX;
        } else {
            x = root.MAIN?.input?.mousePosition.x ?? 0;
            y = y ?? root.MAIN?.input?.mousePosition.y ?? 0;
        }
        const yy = y ?? 0;
        const target = hitTestScenePressTarget(scene, x, yy);
        dispatchSceneMouseUpClicks(scene, x, yy, target);
    },
};

export function installStrippedInput(
    jg: Record<string, unknown>,
    main: Record<string, unknown>,
    canvas: HTMLCanvasElement,
): StrippedInputState {
    const input = createStrippedInput();
    const dom = attachDomInput(canvas);
    (input as StrippedInputState & { __dom?: DomInputBinding }).__dom = dom;
    input.main = main;
    jg.InputModule = StrippedInputModule;
    main.input = input;
    canvas.focus({ preventScroll: true });
    return input;
}
