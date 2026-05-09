export {}
import { clamp } from "../../../../src/engine/core/juliaHelpers";

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
        mouseButtonsPressedDown: Vector
        mouseButtonsHeldDown: Vector
        mouseButtonsReleased: Vector
        mousePosition
        mousePositionEditorGameWindowOffset: Vector2
        mousePositionWorld: Vector2f
        joystick
        scanCodeStrings: string[]
        scanCodes: Vector
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
        cursorBank: SDL_SystemCursor}} // Key is the name of the cursor, value is the SDL2 cursor

        // Testing
        isTestButtonClicked: boolean
        simulatedClickPosition: Vector2 | null

        // SDL events pulled while coalescing SDL_MOUSEMOTION (processed on following poll_input iterations)
        pending_sdl_events: SDL_Event[]

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
            this.scanCodes = []
            this.scanCodeStrings = []
            for (const m of instances(SDL2.SDL_Scancode)) {
                let codeString = "$(m)"
                code = m
                if (codeString == "SDL_NUM_SCANCODES") {
                    continue
                }
                this.scanCodes.push([code, SubString(codeString, 14, codeString.length)])
            }

            (globalThis as any).JulGameSdl.glue_SDL_Init(UInt64(SDL2.SDL_INIT_JOYSTICK))
            if ((globalThis as any).JulGameSdl.glue_SDL_NumJoysticks() < 1) {
                console.debug("Warning: No joysticks connected!")
                this.numAxes = 0
                this.numButtons = 0
                this.numHats = 0
            else
                // Load joystick
                this.joystick = (globalThis as any).JulGameSdl.glue_SDL_JoystickOpen(0)
                if (this.joystick == null) {
                    console.debug("Warning: Unable to open game controller! SDL Error: ", unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))
                }
                let name = (globalThis as any).JulGameSdl.glue_SDL_JoystickName(this.joystick)
                this.numAxes = (globalThis as any).JulGameSdl.glue_SDL_JoystickNumAxes(this.joystick)
                this.numButtons = (globalThis as any).JulGameSdl.glue_SDL_JoystickNumButtons(this.joystick)
                this.numHats = (globalThis as any).JulGameSdl.glue_SDL_JoystickNumHats(this.joystick)

                console.debug("Now reading from joystick '$(unsafe_string(name))' with:")
                console.debug("$(this.numAxes) axes")
                console.debug("$(this.numButtons) buttons")
                console.debug("$(this.numHats) hats")

            }
            this.jaxis = null
            this.xDir = 0
            this.yDir = 0
            this.button = 0

            this.cursorBank = Dict{String, SDL2.SDL_SystemCursor}()
            create_cursor_bank(this)
            this.defaultCursor = this.cursorBank["arrow"]

            this.isTestButtonClicked = false
            this.simulatedClickPosition = null
            this.pending_sdl_events = []

        }
    }

    function _refresh_logical_mouse(this: Input,  evt: SDL_Event) {
        let x = Int32[0]
        let y = Int32[0]
        (globalThis as any).JulGameSdl.glue_SDL_GetMouseState(pointer(x), pointer(y))

        if (evt.type == SDL2.SDL_MOUSEBUTTONDOWN || evt.type == SDL2.SDL_MOUSEBUTTONUP) {
            console.debug("Mouse down: $(evt.type == SDL2.SDL_MOUSEBUTTONDOWN)")
            console.debug("mouse state: $(x[0]), $(y[0])")
            let window_focused = (MAIN !== null && MAIN.windowManager !== null && MAIN.windowManager.isWindowFocused)
            console.debug("window focused: $window_focused")
            if (!window_focused) {
                console.debug("// using event coordinates")
                x[0] = Int32(evt.button.x)
                y[0] = Int32(evt.button.y)
                console.debug("event coordinates: $(x[0]), $(y[0])")
            }
        }

        this.mousePosition = {x: x[0], y: y[0]}
        console.debug("new mouse pos: $(this.mousePosition)")

        if ((globalThis as any).JulGame.IS_EDITOR) {
            let window_width = Ref{Cint}(0)
            let window_height = Ref{Cint}(0)
            (globalThis as any).JulGameSdl.glue_SDL_GetWindowSize(MAIN.windowManager.window, window_width, window_height)
            let logical_size = (globalThis as any).JulGame.WindowManagerModule.get_logical_size()
            let safe_window_width = max(window_width, 1)
            let safe_window_height = max(window_height, 1)
            let safe_logical_width = max(logical_size.x, 1)
            let safe_logical_height = max(logical_size.y, 1)
            let scale_x = safe_window_width / safe_logical_width
            let scale_y = safe_window_height / safe_logical_height
            let scale = min(scale_x, scale_y)
            let content_width = safe_logical_width * scale
            let content_height = safe_logical_height * scale
            let bar_x = (safe_window_width - content_width) / 2
            let bar_y = (safe_window_height - content_height) / 2
            console.debug("letterbox scale: $scale, bar_x: $bar_x, bar_y: $bar_y")
            console.debug("window_width: $window_width, window_height: $window_height")
            console.debug("logical_width: $(logical_size.x), logical_height: $(logical_size.y)")
            let scaled_x = (x[0] - bar_x) / scale
            let scaled_y = (y[0] - bar_y) / scale
            if (scaled_x == Inf || scaled_y == Inf) {
                Base.@logmsg(Base.LogLevel(-1), "Mouse position is infinite")
                scaled_x = 0
                scaled_y = 0
            }
            window_focused = (MAIN !== null && MAIN.windowManager !== null && MAIN.windowManager.isWindowFocused)
            this.mousePosition = Vector2(
                clamp(Math.floor(Int, scaled_x), 0, logical_size.x),
                clamp(Math.floor(Int, scaled_y), 0, logical_size.y)
            )
            console.debug("Scaled mouse position: window coords ($(x[0]), $(y[0])) -> logical coords ($(this.mousePosition.x), $(this.mousePosition.y)), window_focused: $window_focused")
        else
            let raw_mouse_x = x[0] - (globalThis as any).JulGame.EditorGameViewPosition.x
            let raw_mouse_y = y[0] - (globalThis as any).JulGame.EditorGameViewPosition.y
            let clamped_mouse_x = clamp(raw_mouse_x, 0, (globalThis as any).JulGame.EditorGameViewSize.x)
            let clamped_mouse_y = clamp(raw_mouse_y, 0, (globalThis as any).JulGame.EditorGameViewSize.y)
            let camera_size = MAIN.scene.camera.size
            if ((globalThis as any).JulGame.EditorGameViewSize.x > 0 && (globalThis as any).JulGame.EditorGameViewSize.y > 0) {
                scale_x = camera_size.x / (globalThis as any).JulGame.EditorGameViewSize.x
                scale_y = camera_size.y / (globalThis as any).JulGame.EditorGameViewSize.y
                scaled_x = clamped_mouse_x * scale_x
                scaled_y = clamped_mouse_y * scale_y
                this.mousePosition = Vector2(Math.floor(Int, scaled_x), Math.floor(Int, scaled_y))
            else
                this.mousePosition = {x: 0, y: 0}
            }
        }
        return
    }

    function _input_latency_profiler() {
        let m = (globalThis as any).JulGame.MAIN
        (m !== null && m.latencyProfiler !== null && m.latencyProfiler.enabled) || return null
        return m.latencyProfiler
    }

    function _input_poll_accumulate(prof, t0, key: symbol)
        if (prof === null) { return let dt = (time_ns() - t0) / 1e6 }
        (globalThis as any).JulGame.LatencyProfilerModule.accumulate_input_poll_ms(prof, key, dt)
        t0 = time_ns()
        return
    }

    // UI hit-test: timings go to LatencyProfiler (summed per frame, printed only on slow-frame CRITICAL/WARNING reports).
    // Optional live spam: JULGAME_TRACE_INPUT_UI_HIT=1 (every SDL mouse event). Per-element: JULGAME_TRACE_INPUT_UI_HIT_ITER=1.
    function _input_ui_hit_stream_logs() {
        let e = lowercase(strip(get(ENV, "JULGAME_TRACE_INPUT_UI_HIT", "")))
        return e in ("1", "true", "yes", "on")
    }

    const _trace_input_ui_hit_iter_ref = Ref{Union{null, Bool}}(null)
    function _input_ui_hit_iter_stream_logs() {
        let v = _trace_input_ui_hit_iter_ref
        if (v === null) {
            let s = lowercase(strip(get(ENV, "JULGAME_TRACE_INPUT_UI_HIT_ITER", "0")))
            _trace_input_ui_hit_iter_ref = s == "1" || s in ("true", "yes", "on")
        }
        return _trace_input_ui_hit_iter_ref: boolean
    }

    function _input_ui_hit_step(prof,  t_blk: Ref{UInt64},  key: )
        let t1 = time_ns()
        dt = (t1 - t_blk) / 1e6
        t_blk = t1
        if (prof !== null) {
            (globalThis as any).JulGame.LatencyProfilerModule.accumulate_input_ui_hit_detail_ms(prof, key, dt)
        }
        if (_input_ui_hit_stream_logs()) {
            if (isempty(kvs)) {
                console.info("[JulGame input/ui hit-test · stream]") key ms = Math.round(dt, digits = 3)
            else
                console.info("[JulGame input/ui hit-test · stream]") key ms = Math.round(dt, digits = 3) (; kvs...)
            }
        }
        return
    }

    function _input_ui_hit_span(prof,  t0: number,  key: ) {
        dt = (time_ns() - t0) / 1e6
        if (prof !== null) {
            (globalThis as any).JulGame.LatencyProfilerModule.accumulate_input_ui_hit_detail_ms(prof, key, dt)
        }
        if (_input_ui_hit_stream_logs() && _input_ui_hit_iter_stream_logs()) {
            if (isempty(kvs)) {
                console.info("[JulGame input/ui hit-test · stream · iter]") key dur_ms = Math.round(dt, digits = 3)
            else
                console.info("[JulGame input/ui hit-test · stream · iter]") key dur_ms = Math.round(dt, digits = 3) (; kvs...)
            }
        }
        return
    }

    function poll_input(this: Input) {
        prof = _input_latency_profiler()
        t0 = time_ns()

        this.buttonsPressedDown = []
        this.mouseButtonsPressedDown = []
        this.mouseButtonsReleased = []  // Clear the released buttons each frame
        this.didMouseEventOccur = false
        this.didMouseMotionOccur = false
        let event_ref = Ref{SDL2.SDL_Event}()

        while true
            if (!isempty(this.pending_sdl_events)) {
                event_ref = popfirst(this.pending_sdl_events)
            elseif !Bool((globalThis as any).JulGameSdl.glue_SDL_PollEvent(event_ref))
                break
            }
            _input_poll_accumulate(prof, t0, :sdl_PollEvent)

            evt = event_ref
            handle_window_events(this, evt)

            // console.debug("polling input")
            // Only update mouse position for mouse-related events
            if (evt.type == SDL2.SDL_MOUSEMOTION || evt.type == SDL2.SDL_MOUSEBUTTONDOWN || evt.type == SDL2.SDL_MOUSEBUTTONUP) {
                _refresh_logical_mouse(this, evt)
                if (evt.type == SDL2.SDL_MOUSEMOTION) {
                    let coalesce_ref = Ref{SDL2.SDL_Event}()
                    while Bool((globalThis as any).JulGameSdl.glue_SDL_PollEvent(coalesce_ref))
                        let e2 = coalesce_ref
                        if (e2.type == SDL2.SDL_MOUSEMOTION) {
                            _refresh_logical_mouse(this, e2)
                            this.didMouseMotionOccur = true
                        else
                            this.pending_sdl_events.push(e2)
                        }
                    }
                }
            }

            if (this.editorCallback !== null) {
                this.editorCallback(evt)
            }

            let dropped_files = "dropped_files"
            let dropped_texts = "dropped_texts"
            if (evt.type == SDL2.SDL_DROPFILE) {
                console.debug("Dropped file: $(unsafe_string(evt.drop.file))")
                if ((globalThis as any).JulGame.IS_EDITOR) {
                    if (get((globalThis as any).JulGame.EditorState, dropped_files, null) === null) {
                        (globalThis as any).JulGame.EditorState[dropped_files] = [unsafe_string(evt.drop.file)]
                    else
                        (globalThis as any).JulGame.EditorState[dropped_files].push(unsafe_string(evt.drop.file))
                    }
                }
                // TODO: Handle dropped file
                (globalThis as any).JulGameSdl.glue_SDL_free(evt.drop.file)
            elseif evt.type == SDL2.SDL_DROPTEXT
                console.debug("Dropped text: $(unsafe_string(evt.drop.file))")
                if ((globalThis as any).JulGame.IS_EDITOR) {
                    if (get((globalThis as any).JulGame.EditorState, dropped_texts, null) === null) {
                        (globalThis as any).JulGame.EditorState[dropped_texts] = [unsafe_string(evt.drop.file)]
                    else
                        (globalThis as any).JulGame.EditorState[dropped_texts].push(unsafe_string(evt.drop.file))
                    }
                }
                (globalThis as any).JulGameSdl.glue_SDL_free(evt.drop.file)
            elseif evt.type == SDL2.SDL_DROPBEGIN
                console.debug("Drop begin")
            elseif evt.type == SDL2.SDL_DROPCOMPLETE
                console.debug("Drop complete")
            elseif evt.type == SDL2.SDL_CLIPBOARDUPDATE
                console.debug("Clipboard update")
            }

            // Handle Ctrl+V for clipboard paste in editor
            if ((globalThis as any).JulGame.IS_EDITOR && evt.type == SDL2.SDL_KEYDOWN) {
                if (evt.key.keysym.sym == SDL2.LibSDL2.SDLK_v && (evt.key.keysym.mod & SDL2.LibSDL2.KMOD_CTRL) != 0) {
                    console.debug("Ctrl+V detected, checking clipboard for image")
                    handle_clipboard_paste()
                }
            }

            _input_poll_accumulate(prof, t0, :window_routing)

            if (evt.type == SDL2.SDL_MOUSEMOTION || evt.type == SDL2.SDL_MOUSEBUTTONDOWN || evt.type == SDL2.SDL_MOUSEBUTTONUP) {
                let t_ms_blk = time_ns()
                this.didMouseEventOccur = true
                if (evt.type == SDL2.SDL_MOUSEMOTION) {
                    this.didMouseMotionOccur = true
                }
                if (evt.type == SDL2.SDL_MOUSEBUTTONDOWN) {
                    console.debug("Mouse button down at $(this.mousePosition)")
                }

                let ui_hit_active = MAIN.scene.uiElements !== null && ((globalThis as any).JulGame.IS_EDITOR && !MAIN.isGameModeRunningInEditor)
                if (ui_hit_active) {
                    _input_ui_hit_span(prof, t_ms_blk, :hit_mouse_evt_preamble)
                    let t_ui_wall = time_ns()
                    let t_hit = time_ns()
                    _input_ui_hit_step(prof, t_hit, :hit_ui_enter; evt = evt.type, mouse = [this.mousePosition.x, this.mousePosition.y], n_ui = MAIN.scene.uiElements.length)
                    if (MAIN.scene.camera === null) {
                        _input_ui_hit_step(prof, t_hit, :hit_ui_abort_camera)
                        @warn ("Camera is not set in the main scene.")
                        _input_poll_accumulate(prof, t0, :mouse_ui_aborted_no_camera)
                        continue
                    }
                    _input_ui_hit_step(prof, t_hit, :hit_ui_camera_ok)

                    let canvases = filter(x -> isa(x, (globalThis as any).JulGame.ICanvas), MAIN.scene.uiElements)
                    _input_ui_hit_step(prof, t_hit, :hit_ui_filter_canvas; n_canvases = canvases.length)

                    // Use cached layer order instead of sorting every mouse event
                    // This avoids expensive allocations (reverse, sort, filter, vcat) on every input event

                    let uiElementsOrderedByLayerDescending = sort(reverse(MAIN.scene.uiElements), by = uiElement -> uiElement.layer, rev = true)
                    _input_ui_hit_step(prof, t_hit, :hit_ui_sort_ui; n = uiElementsOrderedByLayerDescending.length)

                    let entitiesWithSpritesOrderedByLayerDescending = sort(reverse(filter(entity -> entity.sprite !== null && entity.sprite !== null, MAIN.scene.entities)), by = entity -> entity.sprite.layer, rev = true)
                    _input_ui_hit_step(prof, t_hit, :hit_ui_sort_entities; n = entitiesWithSpritesOrderedByLayerDescending.length, n_entities = MAIN.scene.entities.length)

                    let elementsOrderedByLayerDescending = vcat(uiElementsOrderedByLayerDescending, entitiesWithSpritesOrderedByLayerDescending)
                    _input_ui_hit_step(prof, t_hit, :hit_ui_vcat; n_total = elementsOrderedByLayerDescending.length)

                    // TODO: add rest of entities without sprites in default order
                    // restOfEntities = filter(entity -> entity.sprite === null || entity.sprite === null, MAIN.scene.entities)
                    // append(elementsOrderedByLayerDescending, restOfEntities)
                    let clickedAnElementAlready = false
                    let hoveredAnElementAlready = false
                    console.debug("Checking $(elementsOrderedByLayerDescending.length) elements for mouse event at $(this.mousePosition)")
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
                        if (!skipElement) {
                            for (const canvas of canvases) {
                                if (element in canvas.children && !canvas.isActive) {
                                    skipElement = true
                                    n_skipped_canvas += 1
                                    break
                                }
                            }
                        }
                        if (isa(element, (globalThis as any).JulGame.IEntity) && element.ignoreInputEvents) {
                            skipElement = true
                            if (element.isActive) {
                                n_skipped_ignore += 1
                            }
                        }

                        if (skipElement) {
                            console.debug("Skipping element $(element.name) - isActive: $(element.isActive), ignoreInputEvents: $(isa(element, (globalThis as any).JulGame.IEntity) ? element.ignoreInputEvents : ")N/A")"
                            _input_ui_hit_span(prof, t_iter, :hit_ui_iter_skip_early)
                            continue
                        }

                        _input_ui_hit_span(prof, t_iter, :hit_ui_iter_probe_active_filter)
                        let t_prep0 = time_ns()

                        // Check position of button to see which we are interacting with
                        let eventWasInsideThisElement = true

                        let mouseX = this.mousePosition.x
                        let mouseY = this.mousePosition.y

                        _input_ui_hit_span(prof, t_prep0, :hit_ui_iter_probe_prep_hitbox)
                        let t_geom0 = time_ns()

                        // UI Element position and size in screen space (MUST BE SCALED)
                        let elementPosition = get_element_position(element)
                        _input_ui_hit_span(prof, t_geom0, :hit_ui_iter_probe_get_position)
                        let t_sz0 = time_ns()

                        let elementSize = get_element_size(element)
                        _input_ui_hit_span(prof, t_sz0, :hit_ui_iter_probe_get_size)
                        let t_unpk0 = time_ns()

                        let screenElementX = elementPosition.x
                        let screenElementY = elementPosition.y
                        let screenElementWidth = elementSize.x
                        let screenElementHeight = elementSize.y

                        console.debug("Checking element '$(element.name)': mouse($mouseX, $mouseY) vs element($screenElementX, $screenElementY, $screenElementWidth, $screenElementHeight)")

                        // Check if the mouse is inside the UI element (// using game world coordinates)
                        _input_ui_hit_span(prof, t_unpk0, :hit_ui_iter_probe_unpack_layout)
                        let t_aabb = time_ns()
                        if (mouseX < screenElementX) {
                            eventWasInsideThisElement = false
                            console.debug("  -> Mouse X ($mouseX) < element X ($screenElementX)")
                        elseif mouseX > screenElementX + screenElementWidth
                            eventWasInsideThisElement = false
                            console.debug("  -> Mouse X ($mouseX) > element right ($(screenElementX + screenElementWidth))")
                        elseif mouseY < screenElementY
                            eventWasInsideThisElement = false
                            console.debug("  -> Mouse Y ($mouseY) < element Y ($screenElementY)")
                        elseif mouseY > screenElementY + screenElementHeight
                            eventWasInsideThisElement = false
                            console.debug("  -> Mouse Y ($mouseY) > element bottom ($(screenElementY + screenElementHeight))")
                        }
                        _input_ui_hit_span(prof, t_aabb, :hit_ui_iter_probe_aabb)

                        if (!eventWasInsideThisElement) {
                            element.isHovered = false
                            let t_ctr = time_ns()
                            n_miss_bounds += 1
                            _input_ui_hit_span(prof, t_ctr, :hit_ui_iter_miss_hover_counter_inc)
                            continue
                        }

                        n_hit_inside += 1
                        let t_hi = time_ns()
                        console.debug("  -> Mouse is INSIDE element '$(element.name)'")

                        let clicked_down_here = clicked_down_on_this_element(this, element)
                        _input_ui_hit_span(prof, t_hi, :hit_inside_1_clicked_down_query)
                        t_hi = time_ns()

                        let canClickOnThisElement = (!clickedAnElementAlready || element.forceClickCheck) && clicked_down_here
                        console.debug("  -> canClickOnThisElement: $canClickOnThisElement, clickedAnElementAlready: $clickedAnElementAlready, forceClickCheck: $(element.forceClickCheck), clicked_down_on_this_element: $clicked_down_here")
                        _input_ui_hit_span(prof, t_hi, :hit_inside_2_can_click_bools)
                        t_hi = time_ns()

                        if (!clickedAnElementAlready || element.forceClickCheck) {
                            let shouldHandleEvent = (!hoveredAnElementAlready && evt.type == SDL2.SDL_MOUSEMOTION) ||
                                (element.forceClickCheck && evt.type == SDL2.SDL_MOUSEMOTION) ||
                                (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && !clickedAnElementAlready) ||
                                (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && element.forceClickCheck) ||
                                (canClickOnThisElement && evt.type == SDL2.SDL_MOUSEBUTTONUP)

                            console.debug("  -> shouldHandleEvent: $shouldHandleEvent (event type: $(evt.type), hoveredAnElementAlready: $hoveredAnElementAlready)")
                            _input_ui_hit_span(prof, t_hi, :hit_inside_3a_should_handle_expr)
                            t_hi = time_ns()

                            if (shouldHandleEvent) {
                                console.debug("  -> Handling event for element '$(element.name)'")
                                (globalThis as any).JulGame.UI.handle_event(element, evt, this.mousePosition.x, this.mousePosition.y)
                                t_hi = time_ns()
                                if (evt.type == SDL2.SDL_MOUSEBUTTONDOWN) {
                                   this.elementsBeingClickedDownOn.push(element)
                                   console.debug("  -> Added '$(element.name)' to elementsBeingClickedDownOn")
                                }
                                _input_ui_hit_span(prof, t_hi, :hit_inside_5_push_clicked_down_optional)
                                t_hi = time_ns()
                            else
                                _input_ui_hit_span(prof, t_hi, :hit_inside_4_skip_should_handle_false)
                                t_hi = time_ns()
                            }
                            if (element.isHovered) {
                                hoveredAnElementAlready = true
                            }
                            _input_ui_hit_span(prof, t_hi, :hit_inside_6_hover_an_element_already)
                            t_hi = time_ns()
                        else
                            _input_ui_hit_span(prof, t_hi, :hit_inside_3b_skip_clicked_guard)
                            t_hi = time_ns()
                        }

                        if (evt.type == SDL2.SDL_MOUSEBUTTONDOWN) {
                            console.debug("Mouse button down at $(this.mousePosition) on element '$(element.name)'")
                        elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
                            console.debug("Mouse button up at $(this.mousePosition) on element '$(element.name)'")
                            if (canClickOnThisElement) {
                                console.debug("CLICKED on '$(element.name)' at $(this.mousePosition), skipping rest of event loop")
                            else
                                console.debug("  -> Button up on '$(element.name)' but canClickOnThisElement is false")
                            }
                            clickedAnElementAlready = true
                        }
                        _input_ui_hit_span(prof, t_hi, :hit_inside_7_mouse_btn_tail)
                    }
                    let t_tail = time_ns()
                    if (evt.type == SDL2.SDL_MOUSEBUTTONUP) {
                        this.elementsBeingClickedDownOn = []
                        _input_ui_hit_step(prof, t_tail, :hit_ui_clear_click_state)
                    }
                    _input_ui_hit_step(prof, t_tail, :hit_ui_block_end)
                    _input_ui_hit_span(prof, t_ui_wall, :hit_ui_block_wall_clock)
                else
                    _input_ui_hit_span(prof, t_ms_blk, :hit_mouse_evt_skip_ui_hit_path)
                }

                let t_hm = time_ns()
                handle_mouse_event(this, evt)
                _input_ui_hit_span(prof, t_hm, :hit_mouse_evt_handle_mouse_event)
            }

            _input_poll_accumulate(prof, t0, :mouse_ui_hit_test_dispatch)

            //if evt.type == SDL2.SDL_JOYAXISMOTION
                if (evt.jaxis.which == 0) {
                    this.jaxis = evt.jaxis
                }
                for (const i of 0:this.numAxes-1) {
                    let axis = (globalThis as any).JulGameSdl.glue_SDL_JoystickGetAxis(this.joystick, i)
                    if (i < 0) {
                        console.debug("Axis $i: $((globalThis as any).JulGameSdl.glue_SDL_JoystickGetAxis(this.joystick, i))")
                    }
                    let JOYSTICK_DEAD_ZONE = 8000

                    if (i == 0) {
                        if (axis < -JOYSTICK_DEAD_ZONE) {
                            this.xDir = -1
                        // Right of dead zone
                        elseif axis > JOYSTICK_DEAD_ZONE
                            this.xDir = 1
                        else
                            this.xDir = 0
                        }
                    elseif i == 1
                        if (axis < -JOYSTICK_DEAD_ZONE) {
                            this.yDir = -1
                        // Right of dead zone
                        elseif axis > JOYSTICK_DEAD_ZONE
                            this.yDir = 1
                        else
                            this.yDir = 0
                        }
                    }

                }
                // console.debug("x:$(this.xDir), y:$(this.yDir)")
                for (const i of 0:this.numButtons-1) {
                    let button = (globalThis as any).JulGameSdl.glue_SDL_JoystickGetButton(this.joystick, i)

                    if (button != 0) {
                        console.debug("Button $i: $(button)")
                    }
                    if (i == 0 && button == 1) {
                        this.button = 1
                    elseif i == 0
                        this.button = 0
                    }
                }

                for (const i of 0:this.numHats-1) {

                    let hat = (globalThis as any).JulGameSdl.glue_SDL_JoystickGetHat(this.joystick, i)
                    if (hat != 0) {
                        console.debug("Hat $i: $(hat)")
                    }
                }
            if (evt.type == SDL2.SDL_QUIT) {
                this.quit = true
                _input_poll_accumulate(prof, t0, :joystick_keyboard_state)
                return -1
            }
            if (evt.type == SDL2.SDL_KEYDOWN && evt.key.keysym.scancode == SDL2.SDL_SCANCODE_F3) {
                this.debug = !this.debug
                (globalThis as any).JulGame.IS_DEBUG = (globalThis as any).JulGame.IS_DEBUG
            }

            let keyboardState = unsafe_wrap(Array, (globalThis as any).JulGameSdl.glue_SDL_GetKeyboardState(null), 300; own = false)
            handle_key_event(this, keyboardState)

            _input_poll_accumulate(prof, t0, :joystick_keyboard_state)
        }

        if (this.isTestButtonClicked) {
            lift_mouse_after_simulated_click(this)
        }
    }

    function clicked_down_on_this_element(this: Input,  element: IUIElement | IEntity) {
        return element in this.elementsBeingClickedDownOn
    }

    function get_element_position(element: IUIElement) {
        return element.position
    }

    function get_element_position(element: IEntity) {
        if (element.sprite === null || element.sprite === null) {
            return {x: 0, y: 0}
        }
        let basePosition = element.sprite.lastRenderedScreenPosition === null ? {x: 0, y: 0} : element.sprite.lastRenderedScreenPosition
        let baseSize = element.sprite.lastRenderedScreenSize === null ? {x: 0, y: 0} : element.sprite.lastRenderedScreenSize
        // Center the scaled hitbox over the original sprite position
        let interactionScale = try element.sprite.interactionScale catch; 1.0 }
        if (interactionScale < 1.0) {
            let sizeDiff = Vector2(baseSize.x * (1.0 - interactionScale), baseSize.y * (1.0 - interactionScale))
            return {x: basePosition.x + sizeDiff.x / 2, y: basePosition.y + sizeDiff.y / 2}
        }
        return basePosition
    }

    function get_element_size(element: IUIElement) {
        return element.size
    }

    function get_element_size(element: IEntity) {
        if (element.sprite === null || element.sprite === null) {
            return {x: 0, y: 0}
        }
        baseSize = element.sprite.lastRenderedScreenSize === null ? {x: 0, y: 0} : element.sprite.lastRenderedScreenSize
        // Apply interaction scale to shrink/grow hitbox independently of visual size
        interactionScale = try element.sprite.interactionScale catch; 1.0 }
        return {x: baseSize.x * interactionScale, y: baseSize.y * interactionScale}
    }

    function check_scan_code(this: Input,  keyboardState,  keyState,  scanCodes) {
        for (const scanCode of scanCodes) {
            try {
                if (keyboardState[Int32(scanCode) + 1] == keyState) {
                    return true
                }
            catch
                @error("Error checking scan code $(scanCode) at index $(Int32(scanCode) + 1)")
            }
        }
        return false
    }

    function handle_window_events(this: Input,  event: SDL_Event) {
        if (event.type != SDL2.SDL_WINDOWEVENT) {
            return
        }

        // If we have access to the WindowManager through MAIN, delegate window events to it
        if ((globalThis as any).JulGame.MAIN !== null && (globalThis as any).JulGame.MAIN.windowManager !== null) {
            (globalThis as any).JulGame.WindowManagerModule.handle_window_event(event.window)
        }
    }

    function handle_key_event(this: Input,  keyboardState) {
        let buttonsPressedDown = this.buttonsPressedDown

        let count = 1
        for (const scanCode of this.scanCodes) {
            button = scanCode[1]
            if (check_scan_code(this, keyboardState, 1, [scanCode[0]]) && (button in this.buttonsHeldDown)) {
                buttonsPressedDown.push(button)
                this.buttonsHeldDown.push(button)
            elseif check_scan_code(this, keyboardState, 0, [scanCode[0]])
                if (button in this.buttonsHeldDown) {
                    deleteat(this.buttonsHeldDown, findfirst(x -> x == button, this.buttonsHeldDown))
                }
            }
        }
        this.buttonsPressedDown = buttonsPressedDown
    }

    function handle_mouse_event(this: Input,  event) {
        if (event.button.button == SDL2.SDL_BUTTON_LEFT || event.button.button == SDL2.SDL_BUTTON_MIDDLE || event.button.button == SDL2.SDL_BUTTON_RIGHT) {
            button = event.button.button
            if (event.type == SDL2.SDL_MOUSEBUTTONDOWN && (button in this.mouseButtonsHeldDown)) {
                this.mouseButtonsPressedDown.push(button)
                this.mouseButtonsHeldDown.push(button)
            elseif event.type == SDL2.SDL_MOUSEBUTTONUP && (button in this.mouseButtonsHeldDown)
                this.mouseButtonsReleased.push(button)
                deleteat(this.mouseButtonsHeldDown, findfirst(x -> x == button, this.mouseButtonsHeldDown))
            }
        }
    }

    /*
        handle_clipboard_paste()

    Handle Ctrl+V clipboard paste for images in the editor.
    Checks if clipboard contains image data and creates a temporary file for import.
    */
    function handle_clipboard_paste() {
        try {
            // Try to get image data from platform-specific clipboard
            if (Sys.islinux()) {
                console.debug("Linux detected, attempting to get image from X11 clipboard")
                handle_x11_clipboard_image()
            elseif Sys.isapple()
                console.debug("macOS detected, attempting to get image from clipboard")
                handle_macos_clipboard_image()
            elseif Sys.iswindows()
                console.debug("Windows detected, attempting to get image from clipboard")
                handle_windows_clipboard_image()
            }

            // Only check text clipboard if SDL reports it has text data
            // and avoid errors when clipboard contains binary data
            try {
                if ((globalThis as any).JulGameSdl.glue_SDL_HasClipboardText() == SDL2.SDL_TRUE) {
                    let clipboard_text = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetClipboardText())

                    // Skip if the text looks like an error message from xclip
                    if (occursin("xclip: Error:", clipboard_text) || occursin("ProcessFailedException", clipboard_text)) {
                        console.debug("Skipping clipboard text that appears to be an error message")
                        return
                    }

                    console.debug("Clipboard text: $(clipboard_text[1:min(100, clipboard_text.length)])")

                    // Check if it's a file path to an image
                    if (isfile(clipboard_text) && is_image_file_by_extension(clipboard_text)) {
                        console.debug("Clipboard contains image file path: $(clipboard_text)")
                        add_clipboard_file_to_import_queue(clipboard_text)
                        return
                    }

                    // Check if it's base64 image data (common format: data:image/png;base64,...)
                    if (startswith(clipboard_text, "data:image/")) {
                        console.debug("Clipboard contains base64 image data")
                        handle_base64_image_data(clipboard_text)
                        return
                    }
                }
            } catch (e) {
                console.debug("Error reading text clipboard (likely contains binary data): $(e)")
            }

            // No additional fallback needed - platform-specific functions handle their own cases

        } catch (e) {
            console.error("Error handling clipboard paste: $(e)")
        }
    }

    /*
        handle_x11_clipboard_image()

    Try to get image data from X11 clipboard // using xclip command.
    */
    function handle_x11_clipboard_image() {
        try {
            // Check if xclip is available
            if (success(`which xclip`)) {
                console.debug("xclip found, attempting to get image from clipboard")

                // Try to get PNG data from clipboard
                try {
                    let png_data = read(`xclip -selection clipboard -t image/png -o`)
                    if (png_data.length > 0) {
                        console.debug("Found PNG data in clipboard")
                        // Create temporary file for PNG data
                        let temp_file = tempname() * ".png"
                        open(temp_file, "w") do file
                            write(file, png_data)
                        }
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    }
                } catch (e) {
                    console.debug("No PNG data in clipboard: $(e)")
                }

                // Try to get JPEG data from clipboard
                try {
                    let jpeg_data = read(`xclip -selection clipboard -t image/jpeg -o`)
                    if (jpeg_data.length > 0) {
                        console.debug("Found JPEG data in clipboard")
                        // Create temporary file for JPEG data
                        temp_file = tempname() * ".jpg"
                        open(temp_file, "w") do file
                            write(file, jpeg_data)
                        }
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    }
                } catch (e) {
                    console.debug("No JPEG data in clipboard: $(e)")
                }

                console.debug("No image data found in X11 clipboard")
            else
                console.debug("xclip not available, cannot access X11 clipboard")
            }
        } catch (e) {
            console.warn("Error accessing X11 clipboard: $(e)")
        }
    }

    /*
        handle_macos_clipboard_image()

    Try to get image data from macOS clipboard // using pbpaste command.
    */
    function handle_macos_clipboard_image() {
        try {
            // Check if pbpaste is available (should be on all macOS systems)
            if (success(`which pbpaste`)) {
                console.debug("pbpaste found, attempting to get image from clipboard")

                // Try to get PNG data from clipboard
                try {
                    png_data = read(`pbpaste -pboard general -Prefer png`)
                    if (png_data.length > 0) {
                        console.debug("Found PNG data in clipboard")
                        // Create temporary file for PNG data
                        temp_file = tempname() * ".png"
                        open(temp_file, "w") do file
                            write(file, png_data)
                        }
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    }
                } catch (e) {
                    console.debug("No PNG data in clipboard: $(e)")
                }

                // Try to get TIFF data from clipboard (common on macOS)
                try {
                    let tiff_data = read(`pbpaste -pboard general -Prefer tiff`)
                    if (tiff_data.length > 0) {
                        console.debug("Found TIFF data in clipboard")
                        // Create temporary file for TIFF data
                        temp_file = tempname() * ".tiff"
                        open(temp_file, "w") do file
                            write(file, tiff_data)
                        }
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    }
                } catch (e) {
                    console.debug("No TIFF data in clipboard: $(e)")
                }

                // Try to get JPEG data from clipboard
                try {
                    jpeg_data = read(`pbpaste -pboard general -Prefer jpeg`)
                    if (jpeg_data.length > 0) {
                        console.debug("Found JPEG data in clipboard")
                        // Create temporary file for JPEG data
                        temp_file = tempname() * ".jpg"
                        open(temp_file, "w") do file
                            write(file, jpeg_data)
                        }
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    }
                } catch (e) {
                    console.debug("No JPEG data in clipboard: $(e)")
                }

                console.debug("No image data found in macOS clipboard")
            else
                console.debug("pbpaste not available, cannot access macOS clipboard")
            }
        } catch (e) {
            console.warn("Error accessing macOS clipboard: $(e)")
        }
    }

    /*
        handle_windows_clipboard_image()

    Try to get image data from Windows clipboard // using PowerShell.
    */
    function handle_windows_clipboard_image() {
        try {
            console.debug("Attempting to get image from Windows clipboard // using PowerShell")

            // PowerShell script to get image from clipboard and save as PNG
            let powershell_script = /*
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
            \$clipboard = [System.Windows.Forms.Clipboard]()
            if (\$clipboard -ne \$null) {
                \$temp_file = [System.IO.Path]() + ".png"
                \$clipboard.Save(\$temp_file, [System.Drawing.Imaging.ImageFormat])
                Write-Output \$temp_file
            }
            */

            try {
                // Run PowerShell script
                let result = readchomp(`powershell -Command "$powershell_script"`)
                if (!isempty(result) && isfile(result)) {
                    console.debug("Found image data in Windows clipboard, saved to: $(result)")
                    add_clipboard_file_to_import_queue(result)
                    return
                }
            } catch (e) {
                console.debug("No image data in Windows clipboard: $(e)")
            }

            console.debug("No image data found in Windows clipboard")
        } catch (e) {
            console.warn("Error accessing Windows clipboard: $(e)")
        }
    }

    /*
        is_image_file_by_extension(filepath: string) -> Bool

    Check if file has an image extension.
    */
    function is_image_file_by_extension(filepath: string) {
        let ext = lowercase(splitext(filepath)[2])
        return ext in [".png", ".jpg", ".jpeg", ".bmp", ".tga", ".gif", ".webp"]
    }

    /*
        add_clipboard_file_to_import_queue(filepath: string)

    Add a clipboard file path to the // import queue.
    */
    function add_clipboard_file_to_import_queue(filepath: string) {
        dropped_files = "dropped_files"
        if (get((globalThis as any).JulGame.EditorState, dropped_files, null) === null) {
            (globalThis as any).JulGame.EditorState[dropped_files] = [filepath]
        else
            (globalThis as any).JulGame.EditorState[dropped_files].push(filepath)
        }
        console.debug("Added clipboard file to // import queue: $(basename(filepath))")
    }

    /*
        handle_base64_image_data(data: string)

    Handle base64 encoded image data from clipboard.
    Creates a temporary file and adds it to the // import queue.
    */
    function handle_base64_image_data(data: string) {
        try {
            // Parse the data URL format: data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...
            if (!occursin(";base64,", data)) {
                console.warn("Invalid base64 image data format")
                return
            }

            // Extract MIME type and base64 data
            let parts = split(data, ";base64,")
            if (parts.length != 2) {
                console.warn("Invalid base64 image data format")
                return
            }

            let mime_part = parts[0]
            let base64_data = parts[1]

            // Determine file extension from MIME type
            let extension = ".png"  // default
            if (occursin("image/jpeg", mime_part) || occursin("image/jpg", mime_part)) {
                extension = ".jpg"
            elseif occursin("image/png", mime_part)
                extension = ".png"
            elseif occursin("image/gif", mime_part)
                extension = ".gif"
            elseif occursin("image/bmp", mime_part)
                extension = ".bmp"
            elseif occursin("image/webp", mime_part)
                extension = ".webp"
            }

            // Create temporary file
            let temp_dir = mktempdir()
            let timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
            let temp_filename = "clipboard_image_$(timestamp)$(extension)"
            let temp_filepath = joinpath(temp_dir, temp_filename)

            // Decode base64 and write to file
            let image_data = Base64.base64decode(base64_data)
            write(temp_filepath, image_data)

            console.debug("Created temporary image file from clipboard: $(temp_filepath)")

            // Add to // import queue
            add_clipboard_file_to_import_queue(temp_filepath)

        } catch (e) {
            console.error("Error processing base64 image data: $(e)")
        }
    }

    function update_input_state(this: Input,  data: Dict{String,  Any})
        this.buttonsHeldDown = [key for (key, value) in data if value]
    }

    function get_button_held_down(this: Input,  button: string) {
        if (uppercase(button) in this.buttonsHeldDown) {
            return true
        }
        return false
    }

    function get_button_held_down(button: string) {
        return get_button_held_down(MAIN.input, button)
    }

    function get_button_pressed(button: string) {
        return get_button_pressed(MAIN.input, button)
    }

    function get_button_pressed(this: Input,  button: string) {
        if (uppercase(button) in this.buttonsPressedDown) {
            return true
        }
        return false
    }

    function get_button_released(button: string) {
        return get_button_released(MAIN.input, button)
    }

    function get_button_released(this: Input,  button: string) {
        if (uppercase(button) in this.buttonsReleased) {
            return true
        }
        return false
    }

    function get_mouse_button(this: Input,  button: any) {
        if (button in this.mouseButtonsHeldDown) {
            return true
        }
        return false
    }

    function get_mouse_button(button: any) {
        return get_mouse_button(MAIN.input, button)
    }

    function get_mouse_button_pressed(this: Input,  button: any) {
        if (button in this.mouseButtonsPressedDown) {
            return true
        }
        return false
    }

    function get_mouse_button_pressed(button: any) {
        return get_mouse_button_pressed(MAIN.input, button)
    }

    function get_mouse_button_released(this: Input,  button: any) {
        if (button in this.mouseButtonsReleased) {
            return true
        }
        return false
    }

    function get_mouse_button_released(button: any) {
        return get_mouse_button_released(MAIN.input, button)
    }

    function get_mouse_position(this: Input) {
        return this.mousePosition
    }

    function get_mouse_position() {
        return get_mouse_position(MAIN.input)
    }

    function get_mouse_position_in_world_space(this: Input) {
        return this.mousePositionWorld
    }

    function get_mouse_position_in_world_space() {
        return get_mouse_position_in_world_space(MAIN.input)
    }

    function create_cursor_bank(this: Input) {
        this.cursorBank["arrow"] = (globalThis as any).JulGameSdl.glue_SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_ARROW)
        this.cursorBank["ibeam"] = (globalThis as any).JulGameSdl.glue_SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_IBEAM)
        this.cursorBank["wait"] = (globalThis as any).JulGameSdl.glue_SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_WAIT)
        this.cursorBank["crosshair"] = (globalThis as any).JulGameSdl.glue_SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_CROSSHAIR)
        this.cursorBank["waitarrow"] = (globalThis as any).JulGameSdl.glue_SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_WAITARROW)
        this.cursorBank["sizeall"] = (globalThis as any).JulGameSdl.glue_SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZEALL)
        this.cursorBank["sizenesw"] = (globalThis as any).JulGameSdl.glue_SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENESW)
        this.cursorBank["sizenwse"] = (globalThis as any).JulGameSdl.glue_SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENWSE)
        this.cursorBank["sizewe"] = (globalThis as any).JulGameSdl.glue_SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZEWE)
        this.cursorBank["sizens"] = (globalThis as any).JulGameSdl.glue_SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENS)
        this.cursorBank["no"] = (globalThis as any).JulGameSdl.glue_SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_NO)
        this.cursorBank["hand"] = (globalThis as any).JulGameSdl.glue_SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_HAND)
    }

    // Initialize an SDL_Event instance
    function init_sdl_event()
        // Create a vector of UInt8
        data = UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

         // Convert the vector to a tuple of size 56
        let ntuple_data = Tuple(data)

        // Allocate memory for the SDL_Event class itself {
        let ptr_event = Ptr{SDL2.SDL_Event}(Libc.malloc(sizeof(SDL2.SDL_Event)))  // Allocate memory for SDL_Event struct

        // Now, initialize the data field of the struct // using unsafe_store!
        unsafe_store(ptr_event, (globalThis as any).JulGameSdl.glue_SDL_Event(ntuple_data))

        // Return the pointer to the class return { ptr_event
    }

    function init_mouse_button_event()
        // Allocate memory for SDL_MouseButtonEvent class ptr_event { = Ptr{SDL2.SDL_MouseButtonEvent}(Libc.malloc(sizeof(SDL2.SDL_MouseButtonEvent)))

        // Initialize the fields directly
        unsafe_store(ptr_event, (globalThis as any).JulGameSdl.glue_SDL_MouseButtonEvent(
            0x0,             // type (just an example, you'll set this later)
            0x0,             // timestamp
            0x0,             // windowID
            0x0,             // which (mouse)
            0x0,             // button (mouse button)
            0x0,             // state (pressed/released)
            0x0,             // clicks
            0x0,             // padding
            0x0,             // x (position)
            0x0              // y (position)
        ))

        // Return the pointer to the class return { ptr_event
    }

    function simulate_mouse_click(this: Input,  window: SDL_Window},  x: Number,  y: Number) {
        // Get current window size
        window_width = Ref{Cint}(0)
        window_height = Ref{Cint}(0)
        (globalThis as any).JulGameSdl.glue_SDL_GetWindowSize(window, window_width, window_height)

        // Get base resolution from WindowManager
        logical_size = (globalThis as any).JulGame.WindowManagerModule.get_logical_size()

        safe_window_width = max(window_width, 1)
        safe_window_height = max(window_height, 1)
        safe_logical_width = max(logical_size.x, 1)
        safe_logical_height = max(logical_size.y, 1)
        scale_x = safe_window_width / safe_logical_width
        scale_y = safe_window_height / safe_logical_height
        scale = min(scale_x, scale_y)
        content_width = safe_logical_width * scale
        content_height = safe_logical_height * scale
        bar_x = (safe_window_width - content_width) / 2
        bar_y = (safe_window_height - content_height) / 2

        // Convert logical coordinates to window coordinates (inverse of poll_input mapping)
        let window_x = Math.round(Int, (x * scale) + bar_x)
        let window_y = Math.round(Int, (y * scale) + bar_y)
        x = window_x
        y = window_y
        // Move the mouse to the specified position
        console.debug("Moving mouse to $(x), $(y)")
        (globalThis as any).JulGameSdl.glue_SDL_WarpMouseInWindow(window, x, y)

        // Create a mouse button down event
        mouse_event = init_sdl_event()
        mouse_event.type = SDL2.SDL_MOUSEBUTTONDOWN

        mouse_event.button = (globalThis as any).JulGameSdl.glue_SDL_MouseButtonEvent(
            SDL2.SDL_MOUSEBUTTONDOWN,  // Type of event
            0,                        // Timestamp (0 for automatic)
            0,                        // Window ID (0 for default window)
            0,                        // Which mouse (0 for the primary mouse)
            SDL2.SDL_BUTTON_LEFT,      // Button being pressed
            SDL2.SDL_PRESSED,          // Button state (pressed)
            1,                         // Clicks (1 for single click)
            0,                         // Padding (unused, set to 0)
            x,                         // X position
            y                          // Y position
        )
        (globalThis as any).JulGameSdl.glue_SDL_PushEvent(mouse_event)
        
        // Immediately push button up event as well so both are processed together
        // This is especially important when window isn't focused
        mouse_up_event = init_sdl_event()
        mouse_up_event.type = SDL2.SDL_MOUSEBUTTONUP
        mouse_up_event.button = (globalThis as any).JulGameSdl.glue_SDL_MouseButtonEvent(
            SDL2.SDL_MOUSEBUTTONUP,  // Type of event
            0,                        // Timestamp (0 for automatic)
            0,                        // Window ID (0 for default window)
            0,                        // Which mouse (0 for the primary mouse)
            SDL2.SDL_BUTTON_LEFT,      // Button being pressed
            SDL2.SDL_RELEASED,         // Button state (released)
            1,                         // Clicks (1 for single click)
            0,                         // Padding (unused, set to 0)
            x,                         // X position (same as button down)
            y                          // Y position (same as button down)
        )
        (globalThis as any).JulGameSdl.glue_SDL_PushEvent(mouse_up_event)
        
        this.isTestButtonClicked = false  // No need to lift later since we pushed it immediately
        this.simulatedClickPosition = null
    }

    function simulate_mouse_click(x: Number,  y: Number) {
        simulate_mouse_click(MAIN.input, MAIN.windowManager.window, x, y)
    }

    function lift_mouse_after_simulated_click(this) {
        // Use the stored click position, or current mouse position as fallback
        if (this.simulatedClickPosition !== null) {
            let click_x = Int32(this.simulatedClickPosition.x)
            let click_y = Int32(this.simulatedClickPosition.y)
        else
            // Fallback to current mouse position
            x_ref, y_ref = Ref{Cint}(0), Ref{Cint}(0)
            (globalThis as any).JulGameSdl.glue_SDL_GetMouseState(x_ref, y_ref)
            click_x = Int32(x_ref)
            click_y = Int32(y_ref)
        }
        
        mouse_event = init_sdl_event()
        mouse_event.type = SDL2.SDL_MOUSEBUTTONUP
        mouse_event.button = (globalThis as any).JulGameSdl.glue_SDL_MouseButtonEvent(
            SDL2.SDL_MOUSEBUTTONUP,  // Type of event
            0,                        // Timestamp (0 for automatic)
            0,                        // Window ID (0 for default window)
            0,                        // Which mouse (0 for the primary mouse)
            SDL2.SDL_BUTTON_LEFT,      // Button being pressed
            SDL2.SDL_RELEASED,          // Button state (released)
            1,                         // Clicks (1 for single click)
            0,                         // Padding (unused, set to 0)
            click_x,                   // X position (same as button down)
            click_y                    // Y position (same as button down)
        )
        (globalThis as any).JulGameSdl.glue_SDL_PushEvent(mouse_event)
        this.isTestButtonClicked = false
        this.simulatedClickPosition = null
    }

    function lift_mouse_after_simulated_click() {
        lift_mouse_after_simulated_click(MAIN.input)
    }

    function simulate_key_press(this: Input,  key: string) {
        // Create a keyboard event
        key_event = init_sdl_event()
        key_event.type = SDL2.SDL_KEYDOWN
        key_event.key = (globalThis as any).JulGameSdl.glue_SDL_KeyboardEvent(
            SDL2.SDL_KEYDOWN,  // Type of event
            0,                 // Timestamp (0 for automatic)
            0,                 // Window ID (0 for default window)
            0,                 // State (pressed)
            0,                 // Repeat (0 for no repeat)
            0,                 // Padding
            0,                 // Padding
            (globalThis as any).JulGameSdl.glue_SDL_Keysym(   // Keysym structure
                SDL2.SDL_SCANCODE_SPACE, // Scancode
                0,  // Keycode
                0,                                   // Modifiers (none)
                0                                    // Window ID (0 for default window)
            )
        )
        // key_event.key.keysym.sym = (globalThis as any).JulGameSdl.glue_SDL_Keycode(uppercase(key))
        // key_event.key.keysym.scancode = (globalThis as any).JulGameSdl.glue_SDL_Scancode(uppercase(key))
        // key_event.key.keysym.mod = 0
        // key_event.key.keysym.windowID = 0

        // Push the event to the event queue
        (globalThis as any).JulGameSdl.glue_SDL_PushEvent(key_event)
    }

    function simulate_key_press(key: string) {
        simulate_key_press(MAIN.input, key)
    }

    function get_comma_separated_path(path: string) {
        // Normalize the path to use forward slashes
        let normalized_path = replace(path, '\\' => '/')

        // Split the path into components
        parts = split(normalized_path, '/')

        result = join(parts[1:}], ",")

        return result
    }

    /*
        set_cursor_with_image(this, imagePath, x, y, scale_factor)

        Loads an image as an SDL cursor, applies a scaling factor, and updates the hotspot position.

        // Arguments
        - `this`: The input object storing the cursor reference.
        - `imagePath: string`: Path to the image file.
        - `x: number, y: number`: Original hotspot position in the image.
        - `scale_factor: number`: Scaling factor for resizing the cursor (default = 1.0).

        // Example
        set_cursor_with_image(this, "cursor.png", 10, 10, 2.0)  // Scales up by 2x
    */
    function set_cursor_with_image(this: Input,  imagePath: string,  x: number,  y: number,  scale_factor: number=1.0) {
        let surface = null
        if (haskey((globalThis as any).JulGame.IMAGE_CACHE, get_comma_separated_path(imagePath))) {
            let raw_data = (globalThis as any).JulGame.IMAGE_CACHE[get_comma_separated_path(imagePath)]
            let rw = (globalThis as any).JulGameSdl.glue_SDL_RWFromConstMem(pointer(raw_data), raw_data.length)
            if (rw != null) {
                console.debug("loading cursor from cache")
                console.debug("comma separated path: ", get_comma_separated_path(imagePath))
                surface = SDL2.IMG_Load_RW(rw, 1)
            }
        else
            console.debug("loading cursor from disk")
            surface = SDL2.IMG_Load(pointer(joinpath((globalThis as any).JulGame.BasePath, "assets", "images", imagePath)))
        }
        console.debug("Loading image from disk $(fullPath) for sprite, there are $((globalThis as any).JulGame.IMAGE_CACHE.length) images in cache")

        if (surface == null) {
            console.error("Failed to load cursor image: $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
            return
        }

        // Get original width and height
        let original_width = unsafe_load(surface).w
        let original_height = unsafe_load(surface).h

        // Calculate new dimensions
        let new_width = Int(Math.round(original_width * scale_factor))
        let new_height = Int(Math.round(original_height * scale_factor))

        // Scale the hotspot position
        let new_x = Int(Math.round(x * scale_factor))
        let new_y = Int(Math.round(y * scale_factor))

        // Create a new surface for the scaled image
        let scaled_surface = (globalThis as any).JulGameSdl.glue_SDL_CreateRGBSurface(0, new_width, new_height, 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)

        if (scaled_surface == null) {
            console.error("Failed to create scaled surface: $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
            (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(surface)
            return
        }

        // Scale the image onto the new surface
        (globalThis as any).JulGameSdl.glue_SDL_BlitScaled(surface, null, scaled_surface, null)

        // Create cursor from the scaled surface with adjusted hotspot
        let cursor = (globalThis as any).JulGameSdl.glue_SDL_CreateColorCursor(scaled_surface, new_x, new_y)

        if (cursor != null) {
            set_cursor(cursor)
            this.defaultCursor = cursor
            console.debug("Cursor set successfully! Scaled by $(scale_factor)x, Hotspot: ($new_x, $new_y)")
        else
            console.error("Issue loading cursor: $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
        }

        // Free surfaces to avoid memory leaks
        (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(surface)
        (globalThis as any).JulGameSdl.glue_SDL_FreeSurface(scaled_surface)

        return cursor
    }

    function set_cursor_with_image(imagePath: string,  x: number,  y: number,  scale_factor: number=1.0) {
        set_cursor_with_image(MAIN.input, imagePath, x, y, scale_factor)
    }

    function set_cursor(cursor) {
        (globalThis as any).JulGameSdl.glue_SDL_SetCursor(cursor)
    }

    /*
    collect_canvas_children(canvas, allElements: UIElement[])

    Recursively collects all children of a canvas and its sub-canvases.
    */
    // function collect_canvas_children(canvas, allElements: UIElement[])
    //     for child in canvas.children
    //         allElements.push(child)
    //         // If the child is also a canvas, collect its children recursively
    //         if isa(child, UI.Canvas)
    //             collect_canvas_children(child, allElements)
    //         }
    //     }
    // }
