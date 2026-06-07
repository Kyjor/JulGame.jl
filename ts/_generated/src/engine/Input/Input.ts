import { clamp, time_ns, unsafe_string } from "../../../../src/engine/core/juliaHelpers";

//todo: separate mouse, keyboard, gamepad, and window into their own files

    // using ..JulGame
    // using ..(globalThis as any).JulGame.Math
    // using Dates
    // using Base64

    
    class Input {
        buttonsPressedDown: string[]
        buttonsHeldDown: string[]
        buttonsReleased: string[]
        debug: boolean
        defaultCursor
        didMouseEventOccur: boolean
        didMouseMotionOccur: boolean
        editorCallback: Function | null
        main
        mouseButtonsPressedDown
        mouseButtonsHeldDown
        mouseButtonsReleased
        mousePosition
        mousePositionEditorGameWindowOffset: Vector2
        mousePositionWorld: Vector2f
        joystick
        scanCodeStrings: string[]
        scanCodes
        quit: boolean

        elementsBeingClickedDownOn

        //Gamepad
        jaxis
        xDir
        yDir
        numAxes
        numButtons
        numHats
        button

        // Cursor bank
        cursorBank: Record<string, any> // Key is the name of the cursor, value is the SDL2 cursor

        // Testing
        isTestButtonClicked: boolean
        simulatedClickPosition: Vector2 | null

        // SDL events pulled while coalescing SDL_MOUSEMOTION (processed on following poll_input iterations)
        pending_sdl_events: any[]

        constructor() {
            

            this.buttonsPressedDown = []
            this.buttonsHeldDown = []
            this.buttonsReleased = []
            this.debug = false
            this.didMouseEventOccur = false
            this.didMouseMotionOccur = false
            this.editorCallback = null
            this.mouseButtonsPressedDown = []
            this.mouseButtonsHeldDown = []
            this.mouseButtonsReleased = []
            this.elementsBeingClickedDownOn = []
            this.mousePosition = {x: 0, y: 0}
            this.mousePositionEditorGameWindowOffset = {x: 0, y: 0}
            this.mousePositionWorld = {x: 0, y: 0}
            this.quit = false
            this.scanCodes = (globalThis as any).JulGameSdl.SDL_SCANCODE_ENTRIES.slice()
            this.scanCodeStrings = [];


            (globalThis as any).JulGameSdl.glue_SDL_Init(Number((globalThis as any).JulGameSdl.glue_SDL_INIT_JOYSTICK))
            if ((globalThis as any).JulGameSdl.glue_SDL_NumJoysticks() < 1) {
                console.debug("Warning: No joysticks connected!")
                this.numAxes = 0
                this.numButtons = 0
                this.numHats = 0
            } else {
                // Load joystick
                this.joystick = (globalThis as any).JulGameSdl.glue_SDL_JoystickOpen(0)
                if (this.joystick == null) {
                    console.debug("Warning: Unable to open game controller! SDL Error: ", unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))
                }
                let name = (globalThis as any).JulGameSdl.glue_SDL_JoystickName(this.joystick)
                this.numAxes = (globalThis as any).JulGameSdl.glue_SDL_JoystickNumAxes(this.joystick)
                this.numButtons = (globalThis as any).JulGameSdl.glue_SDL_JoystickNumButtons(this.joystick)
                this.numHats = (globalThis as any).JulGameSdl.glue_SDL_JoystickNumHats(this.joystick)

                console.debug(`Now reading from joystick '${unsafe_string(name)}' with:`)
                console.debug(`${this.numAxes} axes`)
                console.debug(`${this.numButtons} buttons`)
                console.debug(`${this.numHats} hats`)

            }
            this.jaxis = null
            this.xDir = 0
            this.yDir = 0
            this.button = 0

            this.cursorBank = {}
            create_cursor_bank(this)

            this.isTestButtonClicked = false
            this.simulatedClickPosition = null
            this.pending_sdl_events = []
        }
    }

    // include("api.jl")
    // include("clipboard.jl")
    // include("cursor.jl")
    // include("profile.jl")
    // include("test_helpers.jl")
    // include("ui.jl")

    function _refresh_logical_mouse(self: Input, evt: any) {
        let x = [1]
        let y = [1];
        (globalThis as any).JulGameSdl.glue_SDL_GetMouseState(x, y)

        let window_focused = false
        if (evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONDOWN || evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONUP) {
            console.debug(`Mouse down: ${evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONDOWN}`)
            console.debug(`mouse state: ${x[0]}, ${y[0]}`)
            window_focused = ((globalThis as any).JulGame.MAIN !== null && (globalThis as any).JulGame.MAIN.windowManager !== null && (globalThis as any).JulGame.MAIN.windowManager.isWindowFocused)
            console.debug(`window focused: ${window_focused}`)
            if (!window_focused) {
                console.debug("// using event coordinates")
                x[0] = Number(evt.button.x)
                y[0] = Number(evt.button.y)
                console.debug(`event coordinates: ${x[0]}, ${y[0]}`)
            }
        }

        self.mousePosition = {x: x[0], y: y[0]}
        console.debug(`new mouse pos: ${self.mousePosition}`)

        let scale_x = 0
        let scale_y = 0
        let scaled_x = 0
        let scaled_y = 0
        if (!(globalThis as any).JulGame.IS_EDITOR) {
            let window_width = [0]
            let window_height = [0];
            (globalThis as any).JulGameSdl.glue_SDL_GetWindowSize((globalThis as any).JulGame.MAIN.windowManager.window, window_width, window_height)
            let logical_size = (globalThis as any).JulGame.WindowManagerModule.get_logical_size()
            let safe_window_width = Math.max(window_width[0], 1)
            let safe_window_height = Math.max(window_height[0], 1)
            let safe_logical_width = Math.max(logical_size.x, 1)
            let safe_logical_height = Math.max(logical_size.y, 1)
            scale_x = safe_window_width / safe_logical_width
            scale_y = safe_window_height / safe_logical_height
            let scale = Math.min(scale_x, scale_y)
            let content_width = safe_logical_width * scale
            let content_height = safe_logical_height * scale
            let bar_x = (safe_window_width - content_width) / 2
            let bar_y = (safe_window_height - content_height) / 2
            console.debug(`letterbox scale: ${scale}, bar_x: ${bar_x}, bar_y: ${bar_y}`)
            console.debug(`window_width: ${window_width[0]}, window_height: ${window_height[0]}`)
            console.debug(`logical_width: ${logical_size.x}, logical_height: ${logical_size.y}`)
            scaled_x = (x[0] - bar_x) / scale
            scaled_y = (y[0] - bar_y) / scale
            if (scaled_x == Infinity || scaled_y == Infinity) {
                console.error("Mouse position is infinite")
                scaled_x = 0
                scaled_y = 0
            }
            window_focused = ((globalThis as any).JulGame.MAIN !== null && (globalThis as any).JulGame.MAIN.windowManager !== null && (globalThis as any).JulGame.MAIN.windowManager.isWindowFocused)
            self.mousePosition = {x: clamp(Math.floor(scaled_x), 0, logical_size.x), y: clamp(Math.floor(scaled_y), 0, logical_size.y)}
            console.debug(`Scaled mouse position: window coords (${x[0]}, ${y[0]}) -> logical coords (${self.mousePosition.x}, ${self.mousePosition.y}), window_focused: ${window_focused}`)
        } else {
            let raw_mouse_x = x[0] - (globalThis as any).JulGame.EditorGameViewPosition.x
            let raw_mouse_y = y[0] - (globalThis as any).JulGame.EditorGameViewPosition.y
            let clamped_mouse_x = clamp(raw_mouse_x, 0, (globalThis as any).JulGame.EditorGameViewSize.x)
            let clamped_mouse_y = clamp(raw_mouse_y, 0, (globalThis as any).JulGame.EditorGameViewSize.y)
            let camera_size = (globalThis as any).JulGame.MAIN.scene.camera.size
            if ((globalThis as any).JulGame.EditorGameViewSize.x > 0 && (globalThis as any).JulGame.EditorGameViewSize.y > 0) {
                scale_x = camera_size.x / (globalThis as any).JulGame.EditorGameViewSize.x
                scale_y = camera_size.y / (globalThis as any).JulGame.EditorGameViewSize.y
                scaled_x = clamped_mouse_x * scale_x
                scaled_y = clamped_mouse_y * scale_y
                self.mousePosition = {x: Math.floor(scaled_x), y: Math.floor(scaled_y)}
            } else {
                self.mousePosition = {x: 0, y: 0}
            }
        }
        return
    }

    export function poll_input(self: Input) {
        // prof = _input_latency_profiler()
        // t0 = time_ns()

        self.buttonsPressedDown = []
        self.mouseButtonsPressedDown = []
        self.mouseButtonsReleased = []  // Clear the released buttons each frame
        self.didMouseEventOccur = false
        self.didMouseMotionOccur = false
        let event_ref = (globalThis as any).JulGameSdl.glue_SDL_Event()

        while (true) {
            if (self.pending_sdl_events.length > 0) {
                event_ref = self.pending_sdl_events.shift()
            } else if ((globalThis as any).JulGameSdl.glue_SDL_PollEvent(event_ref) == 0) {
                break
            }


            let evt = event_ref
            handle_window_events(self, evt)

            // console.debug("polling input")
            // Only update mouse position for mouse-related events
            if (evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEMOTION || evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONDOWN || evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONUP) {
                _refresh_logical_mouse(self, evt)
                if (evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEMOTION) {
                    let coalesce_ref = (globalThis as any).JulGameSdl.glue_SDL_Event()
                    while ((globalThis as any).JulGameSdl.glue_SDL_PollEvent(coalesce_ref) != 0) {
                        let e2 = coalesce_ref
                        if (e2.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEMOTION) {
                            _refresh_logical_mouse(self, e2)
                            self.didMouseMotionOccur = true
                        } else {
                            self.pending_sdl_events.push(e2)
                        }
                    }
                }
            }

            if (self.editorCallback !== null) {
                self.editorCallback(evt)
            }

            





            if (evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEMOTION || evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONDOWN || evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONUP) {
                let t_ms_blk = time_ns()
                self.didMouseEventOccur = true
                if (evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEMOTION) {
                    self.didMouseMotionOccur = true
                }
                if (evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONDOWN) {
                    console.debug(`Mouse button down at ${self.mousePosition}`)
                }

                let ui_hit_active = (globalThis as any).JulGame.MAIN.scene.uiElements !== null && !((globalThis as any).JulGame.IS_EDITOR && !(globalThis as any).JulGame.MAIN.isGameModeRunningInEditor)
                if (ui_hit_active) {

                    let t_ui_wall = time_ns()
                    let t_hit = time_ns()

                    if ((globalThis as any).JulGame.MAIN.scene.camera === null) {



                        continue
                    }


                    // Use cached layer order instead of sorting every mouse event
                    // This avoids expensive allocations (reverse, sort, filter, vcat) on every input event







let elementsOrderedByLayerDescending = (globalThis as any).JulGame.MAIN.scene.uiElements


                    // TODO: add rest of entities without sprites in default order
                    // restOfEntities = filter(entity => entity.sprite === null || entity.sprite === null, (globalThis as any).JulGame.MAIN.scene.entities)
                    // append(elementsOrderedByLayerDescending, restOfEntities)
                    let clickedAnElementAlready = false
                    let hoveredAnElementAlready = false
                    console.debug(`Checking ${elementsOrderedByLayerDescending.length} elements for mouse event at ${self.mousePosition}`)
                    let n_iter = 0
                    let n_skipped_inactive = 0
                    let n_skipped_canvas = 0
                    let n_skipped_ignore = 0
                    let n_miss_bounds = 0
                    let n_hit_inside = 0
                    for (const element of elementsOrderedByLayerDescending) {
                        n_iter += 1
                        let t_iter = time_ns()

                        let skipElement = !element.isActive
                        if (skipElement) {
                            n_skipped_inactive += 1
                        }
                        // if isa(element, (globalThis as any).JulGame.IEntity) && element.ignoreInputEvents
                        //     skipElement = true
                        //     if element.isActive
                        //         n_skipped_ignore += 1
                        //     }
                        // }

                        if (skipElement) {
                            console.debug(`Skipping element ${element.name} - isActive: ${element.isActive}`)

                            continue
                        }


                        let t_prep0 = time_ns()

                        // Check position of button to see which we are interacting with
                        let eventWasInsideThisElement = true

                        let mouseX = self.mousePosition.x
                        let mouseY = self.mousePosition.y


                        let t_geom0 = time_ns()

                        // UI Element position and size in screen space (MUST BE SCALED)
                        let elementPosition = get_element_position(element)

                        let t_sz0 = time_ns()

                        let elementSize = get_element_size(element)

                        let t_unpk0 = time_ns()

                        let screenElementX = elementPosition.x
                        let screenElementY = elementPosition.y
                        let screenElementWidth = elementSize.x
                        let screenElementHeight = elementSize.y

                        console.debug(`Checking element '${element.name}': mouse(${mouseX}, ${mouseY}) vs element(${screenElementX}, ${screenElementY}, ${screenElementWidth}, ${screenElementHeight})`)

                        // Check if the mouse is inside the UI element (// using game world coordinates)

                        let t_aabb = time_ns()
                        if (mouseX < screenElementX) {
                            eventWasInsideThisElement = false
                            console.debug(`  -> Mouse X (${mouseX}) < element X (${screenElementX})`)
                        } else if (mouseX > screenElementX + screenElementWidth) {
                            eventWasInsideThisElement = false
                            console.debug(`  -> Mouse X (${mouseX}) > element right (${screenElementX + screenElementWidth})`)
                        } else if (mouseY < screenElementY) {
                            eventWasInsideThisElement = false
                            console.debug(`  -> Mouse Y (${mouseY}) < element Y (${screenElementY})`)
                        } else if (mouseY > screenElementY + screenElementHeight) {
                            eventWasInsideThisElement = false
                            console.debug(`  -> Mouse Y (${mouseY}) > element bottom (${screenElementY + screenElementHeight})`)
                        }


                        if (!eventWasInsideThisElement) {
                            element.isHovered = false
                            let t_ctr = time_ns()
                            n_miss_bounds += 1

                            continue
                        }

                        n_hit_inside += 1
                        let t_hi = time_ns()
                        console.debug(`  -> Mouse is INSIDE element '${element.name}'`)

                        let clicked_down_here = clicked_down_on_this_element(self, element)

                        t_hi = time_ns()

                        let canClickOnThisElement = (!clickedAnElementAlready || element.forceClickCheck) && clicked_down_here
                        console.debug(`  -> canClickOnThisElement: ${canClickOnThisElement}, clickedAnElementAlready: ${clickedAnElementAlready}, forceClickCheck: ${element.forceClickCheck}, clicked_down_on_this_element: ${clicked_down_here}`)

                        t_hi = time_ns()

                        if (!clickedAnElementAlready || element.forceClickCheck) {
                            let shouldHandleEvent = (!hoveredAnElementAlready && evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEMOTION) ||
                                (element.forceClickCheck && evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEMOTION) ||
                                (evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONDOWN && !clickedAnElementAlready) ||
                                (evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONDOWN && element.forceClickCheck) ||
                                (canClickOnThisElement && evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONUP)

                            console.debug(`  -> shouldHandleEvent: ${shouldHandleEvent} (event type: ${evt.type}, hoveredAnElementAlready: ${hoveredAnElementAlready})`)

                            t_hi = time_ns()

                            if (shouldHandleEvent) {
                                //console.debug("  -> Handling event for element '$(element.name)'")
                                (globalThis as any).JulGame.UI.handle_event(element, evt, self.mousePosition.x, self.mousePosition.y)
                                t_hi = time_ns()
                                if (evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONDOWN) {
                                   self.elementsBeingClickedDownOn.push(element)
                                   console.debug(`  -> Added '${element.name}' to elementsBeingClickedDownOn`)
                                }

                                t_hi = time_ns()
                            } else {

                                t_hi = time_ns()
                            }
                            if (element.isHovered) {
                                hoveredAnElementAlready = true
                            }

                            t_hi = time_ns()
                        } else {

                            t_hi = time_ns()
                        }

                        if (evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONDOWN) {
                            console.debug(`Mouse button down at ${self.mousePosition} on element '${element.name}'`)
                        } else if (evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONUP) {
                            console.debug(`Mouse button up at ${self.mousePosition} on element '${element.name}'`)
                            if (canClickOnThisElement) {
                                console.debug(`CLICKED on '${element.name}' at ${self.mousePosition}, skipping rest of event loop`)
                            } else {
                                console.debug(`  -> Button up on '${element.name}' but canClickOnThisElement is false`)
                            }
                            clickedAnElementAlready = true
                        }

                    }
                    let t_tail = time_ns()
                    if (evt.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONUP) {
                        self.elementsBeingClickedDownOn = []

                    }


                } else {

                }

                let t_hm = time_ns()
                handle_mouse_event(self, evt)

            }



                // if evt.jaxis.which == 0
                //     self.jaxis = evt.jaxis
                // }
                // for i in 0:self.numAxes-1
                //     axis = (globalThis as any).JulGameSdl.glue_SDL_JoystickGetAxis(self.joystick, i)
                //     if i < 0
                //         console.debug("Axis $i: $((globalThis as any).JulGameSdl.glue_SDL_JoystickGetAxis(self.joystick, i))")
                //     }
                //     JOYSTICK_DEAD_ZONE = 8000

                //     if i == 0
                //         if axis < -JOYSTICK_DEAD_ZONE
                //             self.xDir = -1
                //         // Right of dead zone
                //         elseif axis > JOYSTICK_DEAD_ZONE
                //             self.xDir = 1
                //         else
                //             self.xDir = 0
                //         }
                //     elseif i == 1
                //         if axis < -JOYSTICK_DEAD_ZONE
                //             self.yDir = -1
                //         // Right of dead zone
                //         elseif axis > JOYSTICK_DEAD_ZONE
                //             self.yDir = 1
                //         else
                //             self.yDir = 0
                //         }
                //     }

                // }

                // for i in 0:self.numButtons-1
                //     button = (globalThis as any).JulGameSdl.glue_SDL_JoystickGetButton(self.joystick, i)

                //     if button != 0
                //         console.debug("Button $i: $(button)")
                //     }
                //     if i == 0 && button == 1
                //         self.button = 1
                //     elseif i == 0
                //         self.button = 0
                //     }
                // }

                // for i in 0:self.numHats-1

                //     hat = (globalThis as any).JulGameSdl.glue_SDL_JoystickGetHat(self.joystick, i)
                //     if hat != 0
                //         console.debug("Hat $i: $(hat)")
                //     }
                // }
            if (evt.type == (globalThis as any).JulGameSdl.glue_SDL_QUIT) {
                self.quit = true

                return -1
            }
            if (evt.type == (globalThis as any).JulGameSdl.glue_SDL_KEYDOWN && evt.key.keysym.scancode == (globalThis as any).JulGameSdl.glue_SDL_SCANCODE_F3) {
                self.debug = !self.debug;
                (globalThis as any).JulGame.IS_DEBUG = !(globalThis as any).JulGame.IS_DEBUG
            }

        }

        let keyboardState = (globalThis as any).JulGameSdl.glue_SDL_GetKeyboardState(null)
        handle_key_event(self, keyboardState)

        // if self.isTestButtonClicked
        //     lift_mouse_after_simulated_click(self)
        // }
    }

    function create_cursor_bank(self: Input): void {
        self.defaultCursor = null
    }

    function check_scan_code(self: Input, keyboardState, keyState, scanCodes) {
        for (const scanCode of scanCodes) {
            try {
                let check_code = Number(scanCode)
                if (keyboardState[check_code] == keyState) {
                    return true
                }
            } catch {
                console.error(`Error checking scan code ${scanCode} at index ${Number(scanCode)}`)
            }
        }
        return false
    }

    function get_element_position(element: any): { x: number; y: number } {
        if (element?.position) {
            return { x: element.position.x, y: element.position.y }
        }
        const sprite = element?.sprite
        if (!sprite?.lastRenderedScreenPosition) {
            return { x: 0, y: 0 }
        }
        const basePosition = sprite.lastRenderedScreenPosition
        const baseSize = sprite.lastRenderedScreenSize ?? { x: 0, y: 0 }
        const interactionScale = sprite.interactionScale ?? 1
        if (interactionScale < 1) {
            const sizeDiff = {
                x: baseSize.x * (1 - interactionScale),
                y: baseSize.y * (1 - interactionScale),
            }
            return {
                x: basePosition.x + sizeDiff.x / 2,
                y: basePosition.y + sizeDiff.y / 2,
            }
        }
        return { x: basePosition.x, y: basePosition.y }
    }

    function get_element_size(element: any): { x: number; y: number } {
        if (element?.size) {
            return { x: element.size.x, y: element.size.y }
        }
        const sprite = element?.sprite
        if (!sprite?.lastRenderedScreenSize) {
            return { x: 0, y: 0 }
        }
        const baseSize = sprite.lastRenderedScreenSize
        const interactionScale = sprite.interactionScale ?? 1
        return { x: baseSize.x * interactionScale, y: baseSize.y * interactionScale }
    }

    function clicked_down_on_this_element(self: Input, element: unknown): boolean {
        return self.elementsBeingClickedDownOn.includes(element)
    }

    function handle_window_events(self: Input, event: any) {
        if (event.type != (globalThis as any).JulGameSdl.glue_SDL_WINDOWEVENT) {
            return
        }

        // If we have access to the WindowManager through MAIN, delegate window events to it
        if ((globalThis as any).JulGame.MAIN !== null && (globalThis as any).JulGame.MAIN.windowManager !== null) {
            (globalThis as any).JulGame.WindowManagerModule.handle_window_event(event.window)
        }
    }

    function handle_key_event(self: Input, keyboardState) {
        let buttonsPressedDown = self.buttonsPressedDown

        let count = 1
        for (const scanCode of self.scanCodes) {
            let button = scanCode[1]
            if (check_scan_code(self, keyboardState, 1, [scanCode[0]]) && !(self.buttonsHeldDown.includes(button))) {
                buttonsPressedDown.push(button)
                self.buttonsHeldDown.push(button)
            } else if (check_scan_code(self, keyboardState, 0, [scanCode[0]])) {
                if (self.buttonsHeldDown.includes(button)) {
                    (() => { const a = self.buttonsHeldDown; const i = a.findIndex((x) => x === button); if (i >= 0) a.splice(i, 1); })()
                }
            }
        }
        self.buttonsPressedDown = buttonsPressedDown
    }

    function handle_mouse_event(self: Input, event) {
        if (event.button.button == (globalThis as any).JulGameSdl.glue_SDL_BUTTON_LEFT || event.button.button == (globalThis as any).JulGameSdl.glue_SDL_BUTTON_MIDDLE || event.button.button == (globalThis as any).JulGameSdl.glue_SDL_BUTTON_RIGHT) {
            let button = event.button.button
            if (event.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONDOWN && !(self.mouseButtonsHeldDown.includes(button))) {
                self.mouseButtonsPressedDown.push(button)
                self.mouseButtonsHeldDown.push(button)
            } else if (event.type == (globalThis as any).JulGameSdl.glue_SDL_MOUSEBUTTONUP && (self.mouseButtonsHeldDown.includes(button))) {
                self.mouseButtonsReleased.push(button);
                (() => { const a = self.mouseButtonsHeldDown; const i = a.findIndex((x) => x === button); if (i >= 0) a.splice(i, 1); })()
            }
        }
    }

    export function createInput(): Input {
        return new Input()
    }

    export type TranspiledInput = Input;
    export { Input }
