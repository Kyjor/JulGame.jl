#todo: separate mouse, keyboard, gamepad, and window into their own files
module InputModule
    using ..JulGame
    using ..JulGame.Math
    using Dates
    using Base64

    export Input
    mutable struct Input
        buttonsPressedDown::Vector{String}
        buttonsHeldDown::Vector{String}
        buttonsReleased::Vector{String}
        debug::Bool
        defaultCursor
        didMouseEventOccur::Bool
        didMouseMotionOccur::Bool
        editorCallback::Union{Function, Nothing}
        main
        mouseButtonsPressedDown::Vector
        mouseButtonsHeldDown::Vector
        mouseButtonsReleased::Vector
        mousePosition
        mousePositionEditorGameWindowOffset::Vector2
        mousePositionWorld::Math.Vector2f
        joystick
        scanCodeStrings::Vector{String}
        scanCodes::Vector
        quit::Bool

        elementsBeingClickedDownOn

        #Gamepad
        jaxis
        xDir
        yDir
        numAxes
        numButtons
        numHats
        button

        # Cursor bank
        cursorBank::Dict{String, Ptr{SDL2.SDL_SystemCursor}} # Key is the name of the cursor, value is the SDL2 cursor

        # Testing
        isTestButtonClicked::Bool
        simulatedClickPosition::Union{Math.Vector2, Nothing}

        # SDL events pulled while coalescing SDL_MOUSEMOTION (processed on following poll_input iterations)
        pending_sdl_events::Vector{SDL2.SDL_Event}

        function Input()
            this = new()

            this.buttonsPressedDown = []
            this.buttonsHeldDown = []
            this.buttonsReleased = []
            this.debug = false
            this.didMouseEventOccur = false
            this.didMouseMotionOccur = false
            this.editorCallback = nothing
            this.mouseButtonsPressedDown = []
            this.mouseButtonsHeldDown = []
            this.mouseButtonsReleased = []
            this.elementsBeingClickedDownOn = []
            this.mousePosition = Math.Vector2(0,0)
            this.mousePositionEditorGameWindowOffset = Math.Vector2(0,0)
            this.mousePositionWorld = Math.Vector2f(0,0)
            this.quit = false
            this.scanCodes = []
            this.scanCodeStrings = String[]
            for m in instances(SDL2.SDL_Scancode)
                codeString = "$(m)"
                code::SDL2.SDL_Scancode = m
                if codeString == "SDL_NUM_SCANCODES"
                    continue
                end
                push!(this.scanCodes, [code, SubString(codeString, 14, length(codeString))])
            end

            SDL2.SDL_Init(UInt64(SDL2.SDL_INIT_JOYSTICK))
            if SDL2.SDL_NumJoysticks() < 1
                @debug("Warning: No joysticks connected!")
                this.numAxes = 0
                this.numButtons = 0
                this.numHats = 0
            else
                # Load joystick
                this.joystick = SDL2.SDL_JoystickOpen(0)
                if this.joystick == C_NULL
                    @debug("Warning: Unable to open game controller! SDL Error: ", unsafe_string(SDL2.SDL_GetError()))
                end
                name = SDL2.SDL_JoystickName(this.joystick)
                this.numAxes = SDL2.SDL_JoystickNumAxes(this.joystick)
                this.numButtons = SDL2.SDL_JoystickNumButtons(this.joystick)
                this.numHats = SDL2.SDL_JoystickNumHats(this.joystick)

                @debug("Now reading from joystick '$(unsafe_string(name))' with:")
                @debug("$(this.numAxes) axes")
                @debug("$(this.numButtons) buttons")
                @debug("$(this.numHats) hats")

            end
            this.jaxis = C_NULL
            this.xDir = 0
            this.yDir = 0
            this.button = 0

            this.cursorBank = Dict{String, SDL2.SDL_SystemCursor}()
            create_cursor_bank(this)
            this.defaultCursor = this.cursorBank["arrow"]

            this.isTestButtonClicked = false
            this.simulatedClickPosition = nothing
            this.pending_sdl_events = SDL2.SDL_Event[]

            return this
        end
    end

    function _refresh_logical_mouse!(this::Input, evt::SDL2.SDL_Event)
        x = Int32[1]
        y = Int32[1]
        SDL2.SDL_GetMouseState(pointer(x), pointer(y))

        if evt.type == SDL2.SDL_MOUSEBUTTONDOWN || evt.type == SDL2.SDL_MOUSEBUTTONUP
            @debug "Mouse down: $(evt.type == SDL2.SDL_MOUSEBUTTONDOWN)"
            @debug "mouse state: $(x[1]), $(y[1])"
            window_focused = (MAIN !== nothing && MAIN.windowManager !== nothing && MAIN.windowManager.isWindowFocused)
            @debug "window focused: $window_focused"
            if !window_focused
                @debug "using event coordinates"
                x[1] = Int32(evt.button.x)
                y[1] = Int32(evt.button.y)
                @debug "event coordinates: $(x[1]), $(y[1])"
            end
        end

        this.mousePosition = Math.Vector2(x[1], y[1])
        @debug "new mouse pos: $(this.mousePosition)"

        if !JulGame.IS_EDITOR
            window_width = Ref{Cint}(0)
            window_height = Ref{Cint}(0)
            SDL2.SDL_GetWindowSize(MAIN.windowManager.window, window_width, window_height)
            logical_size = JulGame.WindowManagerModule.get_logical_size()
            safe_window_width = max(window_width[], 1)
            safe_window_height = max(window_height[], 1)
            safe_logical_width = max(logical_size.x, 1)
            safe_logical_height = max(logical_size.y, 1)
            scale_x = safe_window_width / safe_logical_width
            scale_y = safe_window_height / safe_logical_height
            scale = min(scale_x, scale_y)
            content_width = safe_logical_width * scale
            content_height = safe_logical_height * scale
            bar_x = (safe_window_width - content_width) / 2
            bar_y = (safe_window_height - content_height) / 2
            @debug("letterbox scale: $scale, bar_x: $bar_x, bar_y: $bar_y")
            @debug("window_width: $window_width[], window_height: $window_height[]")
            @debug("logical_width: $(logical_size.x), logical_height: $(logical_size.y)")
            scaled_x = (x[1] - bar_x) / scale
            scaled_y = (y[1] - bar_y) / scale
            if scaled_x == Inf || scaled_y == Inf
                Base.@logmsg(Base.LogLevel(-1), "Mouse position is infinite")
                scaled_x = 0
                scaled_y = 0
            end
            window_focused = (MAIN !== nothing && MAIN.windowManager !== nothing && MAIN.windowManager.isWindowFocused)
            this.mousePosition = Math.Vector2(
                clamp(floor(Int, scaled_x), 0, logical_size.x),
                clamp(floor(Int, scaled_y), 0, logical_size.y)
            )
            @debug "Scaled mouse position: window coords ($(x[1]), $(y[1])) -> logical coords ($(this.mousePosition.x), $(this.mousePosition.y)), window_focused: $window_focused"
        else
            raw_mouse_x = x[1] - JulGame.EditorGameViewPosition.x
            raw_mouse_y = y[1] - JulGame.EditorGameViewPosition.y
            clamped_mouse_x = clamp(raw_mouse_x, 0, JulGame.EditorGameViewSize.x)
            clamped_mouse_y = clamp(raw_mouse_y, 0, JulGame.EditorGameViewSize.y)
            camera_size = MAIN.scene.camera.size
            if JulGame.EditorGameViewSize.x > 0 && JulGame.EditorGameViewSize.y > 0
                scale_x = camera_size.x / JulGame.EditorGameViewSize.x
                scale_y = camera_size.y / JulGame.EditorGameViewSize.y
                scaled_x = clamped_mouse_x * scale_x
                scaled_y = clamped_mouse_y * scale_y
                this.mousePosition = Math.Vector2(floor(Int, scaled_x), floor(Int, scaled_y))
            else
                this.mousePosition = Math.Vector2(0, 0)
            end
        end
        return
    end

    @inline function _input_latency_profiler()
        m = JulGame.MAIN
        (m !== nothing && m.latencyProfiler !== nothing && m.latencyProfiler.enabled) || return nothing
        return m.latencyProfiler
    end

    @inline function _input_poll_accumulate!(prof, t0::Ref{UInt64}, key::Symbol)
        prof === nothing && return
        dt = (time_ns() - t0[]) / 1e6
        JulGame.LatencyProfilerModule.accumulate_input_poll_ms!(prof, key, dt)
        t0[] = time_ns()
        return
    end

    # UI hit-test: timings go to LatencyProfiler (summed per frame, printed only on slow-frame CRITICAL/WARNING reports).
    # Optional live spam: JULGAME_TRACE_INPUT_UI_HIT=1 (every SDL mouse event). Per-element: JULGAME_TRACE_INPUT_UI_HIT_ITER=1.
    function _input_ui_hit_stream_logs()
        e = lowercase(strip(get(ENV, "JULGAME_TRACE_INPUT_UI_HIT", "")))
        return e in ("1", "true", "yes", "on")
    end

    const _trace_input_ui_hit_iter_ref = Ref{Union{Nothing, Bool}}(nothing)
    function _input_ui_hit_iter_stream_logs()
        v = _trace_input_ui_hit_iter_ref[]
        if v === nothing
            s = lowercase(strip(get(ENV, "JULGAME_TRACE_INPUT_UI_HIT_ITER", "0")))
            _trace_input_ui_hit_iter_ref[] = s == "1" || s in ("true", "yes", "on")
        end
        return _trace_input_ui_hit_iter_ref[]::Bool
    end

    function _input_ui_hit_step!(prof, t_blk::Ref{UInt64}, key::Symbol; kvs...)
        t1 = time_ns()
        dt = (t1 - t_blk[]) / 1e6
        t_blk[] = t1
        if prof !== nothing
            JulGame.LatencyProfilerModule.accumulate_input_ui_hit_detail_ms!(prof, key, dt)
        end
        if _input_ui_hit_stream_logs()
            if isempty(kvs)
                @info "[JulGame input/ui hit-test · stream]" key ms = round(dt, digits = 3)
            else
                @info "[JulGame input/ui hit-test · stream]" key ms = round(dt, digits = 3) (; kvs...)
            end
        end
        return
    end

    function _input_ui_hit_span!(prof, t0::UInt64, key::Symbol; kvs...)
        dt = (time_ns() - t0) / 1e6
        if prof !== nothing
            JulGame.LatencyProfilerModule.accumulate_input_ui_hit_detail_ms!(prof, key, dt)
        end
        if _input_ui_hit_stream_logs() && _input_ui_hit_iter_stream_logs()
            if isempty(kvs)
                @info "[JulGame input/ui hit-test · stream · iter]" key dur_ms = round(dt, digits = 3)
            else
                @info "[JulGame input/ui hit-test · stream · iter]" key dur_ms = round(dt, digits = 3) (; kvs...)
            end
        end
        return
    end

    function poll_input(this::Input)
        prof = _input_latency_profiler()
        t0 = Ref(time_ns())

        this.buttonsPressedDown = []
        this.mouseButtonsPressedDown = []
        this.mouseButtonsReleased = []  # Clear the released buttons each frame
        this.didMouseEventOccur = false
        this.didMouseMotionOccur = false
        event_ref = Ref{SDL2.SDL_Event}()

        while true
            if !isempty(this.pending_sdl_events)
                event_ref[] = popfirst!(this.pending_sdl_events)
            elseif !Bool(SDL2.SDL_PollEvent(event_ref))
                break
            end
            _input_poll_accumulate!(prof, t0, :sdl_PollEvent)

            evt = event_ref[]
            handle_window_events(this, evt)

            # @debug "polling input"
            # Only update mouse position for mouse-related events
            if evt.type == SDL2.SDL_MOUSEMOTION || evt.type == SDL2.SDL_MOUSEBUTTONDOWN || evt.type == SDL2.SDL_MOUSEBUTTONUP
                _refresh_logical_mouse!(this, evt)
                if evt.type == SDL2.SDL_MOUSEMOTION
                    coalesce_ref = Ref{SDL2.SDL_Event}()
                    while Bool(SDL2.SDL_PollEvent(coalesce_ref))
                        e2 = coalesce_ref[]
                        if e2.type == SDL2.SDL_MOUSEMOTION
                            _refresh_logical_mouse!(this, e2)
                            this.didMouseMotionOccur = true
                        else
                            push!(this.pending_sdl_events, e2)
                        end
                    end
                end
            end

            if this.editorCallback !== nothing
                this.editorCallback(evt)
            end

            dropped_files = "dropped_files"
            dropped_texts = "dropped_texts"
            if evt.type == SDL2.SDL_DROPFILE
                @debug "Dropped file: $(unsafe_string(evt.drop.file))"
                if JulGame.IS_EDITOR
                    if get(JulGame.EditorState, dropped_files, nothing) === nothing
                        JulGame.EditorState[dropped_files] = [unsafe_string(evt.drop.file)]
                    else
                        push!(JulGame.EditorState[dropped_files], unsafe_string(evt.drop.file))
                    end
                end
                # TODO: Handle dropped file
                SDL2.SDL_free(evt.drop.file)
            elseif evt.type == SDL2.SDL_DROPTEXT
                @debug "Dropped text: $(unsafe_string(evt.drop.file))"
                if JulGame.IS_EDITOR
                    if get(JulGame.EditorState, dropped_texts, nothing) === nothing
                        JulGame.EditorState[dropped_texts] = [unsafe_string(evt.drop.file)]
                    else
                        push!(JulGame.EditorState[dropped_texts], unsafe_string(evt.drop.file))
                    end
                end
                SDL2.SDL_free(evt.drop.file)
            elseif evt.type == SDL2.SDL_DROPBEGIN
                @debug "Drop begin"
            elseif evt.type == SDL2.SDL_DROPCOMPLETE
                @debug "Drop complete"
            elseif evt.type == SDL2.SDL_CLIPBOARDUPDATE
                @debug "Clipboard update"
            end

            # Handle Ctrl+V for clipboard paste in editor
            if JulGame.IS_EDITOR && evt.type == SDL2.SDL_KEYDOWN
                if evt.key.keysym.sym == SDL2.LibSDL2.SDLK_v && (evt.key.keysym.mod & SDL2.LibSDL2.KMOD_CTRL) != 0
                    @debug "Ctrl+V detected, checking clipboard for image"
                    handle_clipboard_paste()
                end
            end

            _input_poll_accumulate!(prof, t0, :window_routing)

            if evt.type == SDL2.SDL_MOUSEMOTION || evt.type == SDL2.SDL_MOUSEBUTTONDOWN || evt.type == SDL2.SDL_MOUSEBUTTONUP
                t_ms_blk = time_ns()
                this.didMouseEventOccur = true
                if evt.type == SDL2.SDL_MOUSEMOTION
                    this.didMouseMotionOccur = true
                end
                if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
                    @debug("Mouse button down at $(this.mousePosition)")
                end

                ui_hit_active = MAIN.scene.uiElements !== nothing && !(JulGame.IS_EDITOR && !MAIN.isGameModeRunningInEditor)
                if ui_hit_active
                    _input_ui_hit_span!(prof, t_ms_blk, :hit_mouse_evt_preamble)
                    t_ui_wall = time_ns()
                    t_hit = Ref(time_ns())
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_enter; evt = evt.type, mouse = (this.mousePosition.x, this.mousePosition.y), n_ui = length(MAIN.scene.uiElements))
                    if MAIN.scene.camera === nothing
                        _input_ui_hit_step!(prof, t_hit, :hit_ui_abort_camera)
                        @warn ("Camera is not set in the main scene.")
                        _input_poll_accumulate!(prof, t0, :mouse_ui_aborted_no_camera)
                        continue
                    end
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_camera_ok)

                    canvases = filter(x -> isa(x, JulGame.ICanvas), MAIN.scene.uiElements)
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_filter_canvas; n_canvases = length(canvases))

                    # Use cached layer order instead of sorting every mouse event
                    # This avoids expensive allocations (reverse, sort, filter, vcat) on every input event
                    #elementsOrderedByLayerDescending = JulGame.MainLoopModule.get_input_layer_order(MAIN)
                                        # uiElementsOrderedByLayerDescending = sort(reverse(allUIElements), by = uiElement -> uiElement.layer, rev = true)

                    uiElementsOrderedByLayerDescending = sort(reverse(MAIN.scene.uiElements), by = uiElement -> uiElement.layer, rev = true)
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_sort_ui; n = length(uiElementsOrderedByLayerDescending))

                    entitiesWithSpritesOrderedByLayerDescending = sort(reverse(filter(entity -> entity.sprite !== nothing && entity.sprite !== C_NULL, MAIN.scene.entities)), by = entity -> entity.sprite.layer, rev = true)
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_sort_entities; n = length(entitiesWithSpritesOrderedByLayerDescending), n_entities = length(MAIN.scene.entities))

                    elementsOrderedByLayerDescending = vcat(uiElementsOrderedByLayerDescending, entitiesWithSpritesOrderedByLayerDescending)
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_vcat; n_total = length(elementsOrderedByLayerDescending))

                    # TODO: add rest of entities without sprites in default order
                    # restOfEntities = filter(entity -> entity.sprite === nothing || entity.sprite === C_NULL, MAIN.scene.entities)
                    # append!(elementsOrderedByLayerDescending, restOfEntities)
                    clickedAnElementAlready = false
                    hoveredAnElementAlready = false
                    @debug "Checking $(length(elementsOrderedByLayerDescending)) elements for mouse event at $(this.mousePosition)"
                    n_iter = 0
                    n_skipped_inactive = 0
                    n_skipped_canvas = 0
                    n_skipped_ignore = 0
                    n_miss_bounds = 0
                    n_hit_inside = 0
                    for element in elementsOrderedByLayerDescending
                        n_iter += 1
                        t_iter = time_ns()

                        skipElement = !element.isActive
                        if skipElement
                            n_skipped_inactive += 1
                        end
                        if !skipElement
                            for canvas in canvases
                                if element in canvas.children && !canvas.isActive
                                    skipElement = true
                                    n_skipped_canvas += 1
                                    break
                                end
                            end
                        end
                        if isa(element, JulGame.IEntity) && element.ignoreInputEvents
                            skipElement = true
                            if element.isActive
                                n_skipped_ignore += 1
                            end
                        end

                        if skipElement
                            @debug "Skipping element $(element.name) - isActive: $(element.isActive), ignoreInputEvents: $(isa(element, JulGame.IEntity) ? element.ignoreInputEvents : "N/A")"
                            _input_ui_hit_span!(prof, t_iter, :hit_ui_iter_skip_early)
                            continue
                        end

                        _input_ui_hit_span!(prof, t_iter, :hit_ui_iter_probe_active_filter)
                        t_prep0 = time_ns()

                        # Check position of button to see which we are interacting with
                        eventWasInsideThisElement = true

                        mouseX = this.mousePosition.x
                        mouseY = this.mousePosition.y

                        _input_ui_hit_span!(prof, t_prep0, :hit_ui_iter_probe_prep_hitbox)
                        t_geom0 = time_ns()

                        # UI Element position and size in screen space (MUST BE SCALED)
                        elementPosition = get_element_position(element)
                        _input_ui_hit_span!(prof, t_geom0, :hit_ui_iter_probe_get_position)
                        t_sz0 = time_ns()

                        elementSize = get_element_size(element)
                        _input_ui_hit_span!(prof, t_sz0, :hit_ui_iter_probe_get_size)
                        t_unpk0 = time_ns()

                        screenElementX = elementPosition.x
                        screenElementY = elementPosition.y
                        screenElementWidth = elementSize.x
                        screenElementHeight = elementSize.y

                        @debug "Checking element '$(element.name)': mouse($mouseX, $mouseY) vs element($screenElementX, $screenElementY, $screenElementWidth, $screenElementHeight)"

                        # Check if the mouse is inside the UI element (using game world coordinates)
                        _input_ui_hit_span!(prof, t_unpk0, :hit_ui_iter_probe_unpack_layout)
                        t_aabb = time_ns()
                        if mouseX < screenElementX
                            eventWasInsideThisElement = false
                            @debug "  -> Mouse X ($mouseX) < element X ($screenElementX)"
                        elseif mouseX > screenElementX + screenElementWidth
                            eventWasInsideThisElement = false
                            @debug "  -> Mouse X ($mouseX) > element right ($(screenElementX + screenElementWidth))"
                        elseif mouseY < screenElementY
                            eventWasInsideThisElement = false
                            @debug "  -> Mouse Y ($mouseY) < element Y ($screenElementY)"
                        elseif mouseY > screenElementY + screenElementHeight
                            eventWasInsideThisElement = false
                            @debug "  -> Mouse Y ($mouseY) > element bottom ($(screenElementY + screenElementHeight))"
                        end
                        @info "time_ns() - t_aabb: $(t_aabb/1e6) ms"
                        _input_ui_hit_span!(prof, t_aabb, :hit_ui_iter_probe_aabb)

                        if !eventWasInsideThisElement
                            element.isHovered = false
                            t_ctr = time_ns()
                            n_miss_bounds += 1
                            _input_ui_hit_span!(prof, t_ctr, :hit_ui_iter_miss_hover_counter_inc)
                            continue
                        end

                        n_hit_inside += 1
                        t_hi = time_ns()
                        @debug "  -> Mouse is INSIDE element '$(element.name)'"

                        clicked_down_here = clicked_down_on_this_element(this, element)
                        _input_ui_hit_span!(prof, t_hi, :hit_inside_1_clicked_down_query)
                        t_hi = time_ns()

                        canClickOnThisElement = (!clickedAnElementAlready || element.forceClickCheck) && clicked_down_here
                        @debug "  -> canClickOnThisElement: $canClickOnThisElement, clickedAnElementAlready: $clickedAnElementAlready, forceClickCheck: $(element.forceClickCheck), clicked_down_on_this_element: $clicked_down_here"
                        _input_ui_hit_span!(prof, t_hi, :hit_inside_2_can_click_bools)
                        t_hi = time_ns()

                        if !clickedAnElementAlready || element.forceClickCheck
                            shouldHandleEvent = (!hoveredAnElementAlready && evt.type == SDL2.SDL_MOUSEMOTION) ||
                                (element.forceClickCheck && evt.type == SDL2.SDL_MOUSEMOTION) ||
                                (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && !clickedAnElementAlready) ||
                                (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && element.forceClickCheck) ||
                                (canClickOnThisElement && evt.type == SDL2.SDL_MOUSEBUTTONUP)

                            @debug "  -> shouldHandleEvent: $shouldHandleEvent (event type: $(evt.type), hoveredAnElementAlready: $hoveredAnElementAlready)"
                            _input_ui_hit_span!(prof, t_hi, :hit_inside_3a_should_handle_expr)
                            t_hi = time_ns()

                            if shouldHandleEvent
                                @debug "  -> Handling event for element '$(element.name)'"
                                JulGame.UI.handle_event(element, evt, this.mousePosition.x, this.mousePosition.y)
                                t_hi = time_ns()
                                if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
                                   push!(this.elementsBeingClickedDownOn, element)
                                   @debug "  -> Added '$(element.name)' to elementsBeingClickedDownOn"
                                end
                                _input_ui_hit_span!(prof, t_hi, :hit_inside_5_push_clicked_down_optional)
                                t_hi = time_ns()
                            else
                                _input_ui_hit_span!(prof, t_hi, :hit_inside_4_skip_should_handle_false)
                                t_hi = time_ns()
                            end
                            if element.isHovered
                                hoveredAnElementAlready = true
                            end
                            _input_ui_hit_span!(prof, t_hi, :hit_inside_6_hover_an_element_already)
                            t_hi = time_ns()
                        else
                            _input_ui_hit_span!(prof, t_hi, :hit_inside_3b_skip_clicked_guard)
                            t_hi = time_ns()
                        end

                        if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
                            @debug "Mouse button down at $(this.mousePosition) on element '$(element.name)'"
                        elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
                            @debug "Mouse button up at $(this.mousePosition) on element '$(element.name)'"
                            if canClickOnThisElement
                                @debug "CLICKED on '$(element.name)' at $(this.mousePosition), skipping rest of event loop"
                            else
                                @debug "  -> Button up on '$(element.name)' but canClickOnThisElement is false"
                            end
                            clickedAnElementAlready = true
                        end
                        _input_ui_hit_span!(prof, t_hi, :hit_inside_7_mouse_btn_tail)
                    end
                    t_tail = Ref(time_ns())
                    if evt.type == SDL2.SDL_MOUSEBUTTONUP
                        this.elementsBeingClickedDownOn = []
                        _input_ui_hit_step!(prof, t_tail, :hit_ui_clear_click_state)
                    end
                    _input_ui_hit_step!(prof, t_tail, :hit_ui_block_end)
                    _input_ui_hit_span!(prof, t_ui_wall, :hit_ui_block_wall_clock)
                else
                    _input_ui_hit_span!(prof, t_ms_blk, :hit_mouse_evt_skip_ui_hit_path)
                end

                t_hm = time_ns()
                handle_mouse_event(this, evt)
                _input_ui_hit_span!(prof, t_hm, :hit_mouse_evt_handle_mouse_event)
            end

            _input_poll_accumulate!(prof, t0, :mouse_ui_hit_test_dispatch)

            #if evt.type == SDL2.SDL_JOYAXISMOTION
                if evt.jaxis.which == 0
                    this.jaxis = evt.jaxis
                end
                for i in 0:this.numAxes-1
                    axis = SDL2.SDL_JoystickGetAxis(this.joystick, i)
                    if i < 0
                        @debug("Axis $i: $(SDL2.SDL_JoystickGetAxis(this.joystick, i))")
                    end
                    JOYSTICK_DEAD_ZONE = 8000

                    if i == 0
                        if axis < -JOYSTICK_DEAD_ZONE
                            this.xDir = -1
                        # Right of dead zone
                        elseif axis > JOYSTICK_DEAD_ZONE
                            this.xDir = 1
                        else
                            this.xDir = 0
                        end
                    elseif i == 1
                        if axis < -JOYSTICK_DEAD_ZONE
                            this.yDir = -1
                        # Right of dead zone
                        elseif axis > JOYSTICK_DEAD_ZONE
                            this.yDir = 1
                        else
                            this.yDir = 0
                        end
                    end

                end
                # @debug("x:$(this.xDir), y:$(this.yDir)")
                for i in 0:this.numButtons-1
                    button = SDL2.SDL_JoystickGetButton(this.joystick, i)

                    if button != 0
                        @debug("Button $i: $(button)")
                    end
                    if i == 0 && button == 1
                        this.button = 1
                    elseif i == 0
                        this.button = 0
                    end
                end

                for i in 0:this.numHats-1

                    hat = SDL2.SDL_JoystickGetHat(this.joystick, i)
                    if hat != 0
                        @debug("Hat $i: $(hat)")
                    end
                end
            if evt.type == SDL2.SDL_QUIT
                this.quit = true
                _input_poll_accumulate!(prof, t0, :joystick_keyboard_state)
                return -1
            end
            if evt.type == SDL2.SDL_KEYDOWN && evt.key.keysym.scancode == SDL2.SDL_SCANCODE_F3
                this.debug = !this.debug
                JulGame.IS_DEBUG = !JulGame.IS_DEBUG
            end

            keyboardState = unsafe_wrap(Array, SDL2.SDL_GetKeyboardState(C_NULL), 300; own = false)
            handle_key_event(this, keyboardState)

            _input_poll_accumulate!(prof, t0, :joystick_keyboard_state)
        end

        if this.isTestButtonClicked
            lift_mouse_after_simulated_click(this)
        end
    end

    function clicked_down_on_this_element(this::Input, element::Union{JulGame.IUIElement, JulGame.IEntity})
        return element in this.elementsBeingClickedDownOn
    end

    function get_element_position(element::JulGame.IUIElement)
        return element.position
    end

    function get_element_position(element::JulGame.IEntity)
        if element.sprite === nothing || element.sprite === C_NULL
            return Math.Vector2(0, 0)
        end
        basePosition = element.sprite.lastRenderedScreenPosition === nothing ? Math.Vector2(0, 0) : element.sprite.lastRenderedScreenPosition
        baseSize = element.sprite.lastRenderedScreenSize === nothing ? Math.Vector2(0, 0) : element.sprite.lastRenderedScreenSize
        # Center the scaled hitbox over the original sprite position
        interactionScale = try element.sprite.interactionScale catch; 1.0 end
        if interactionScale < 1.0
            sizeDiff = Math.Vector2(baseSize.x * (1.0 - interactionScale), baseSize.y * (1.0 - interactionScale))
            return Math.Vector2(basePosition.x + sizeDiff.x / 2, basePosition.y + sizeDiff.y / 2)
        end
        return basePosition
    end

    function get_element_size(element::JulGame.IUIElement)
        return element.size
    end

    function get_element_size(element::JulGame.IEntity)
        if element.sprite === nothing || element.sprite === C_NULL
            return Math.Vector2(0, 0)
        end
        baseSize = element.sprite.lastRenderedScreenSize === nothing ? Math.Vector2(0, 0) : element.sprite.lastRenderedScreenSize
        # Apply interaction scale to shrink/grow hitbox independently of visual size
        interactionScale = try element.sprite.interactionScale catch; 1.0 end
        return Math.Vector2(baseSize.x * interactionScale, baseSize.y * interactionScale)
    end

    function check_scan_code(this::Input, keyboardState, keyState, scanCodes)
        for scanCode in scanCodes
            try
                if keyboardState[Int32(scanCode) + 1] == keyState
                    return true
                end
            catch
                @error("Error checking scan code $(scanCode) at index $(Int32(scanCode) + 1)")
            end
        end
        return false
    end

    function handle_window_events(this::Input, event::SDL2.SDL_Event)
        if event.type != SDL2.SDL_WINDOWEVENT
            return
        end

        # If we have access to the WindowManager through MAIN, delegate window events to it
        if JulGame.MAIN !== nothing && JulGame.MAIN.windowManager !== nothing
            JulGame.WindowManagerModule.handle_window_event(event.window)
        end
    end

    function handle_key_event(this::Input, keyboardState)
        buttonsPressedDown = this.buttonsPressedDown

        count = 1
        for scanCode in this.scanCodes
            button = scanCode[2]
            if check_scan_code(this, keyboardState, 1, [scanCode[1]]) && !(button in this.buttonsHeldDown)
                push!(buttonsPressedDown, button)
                push!(this.buttonsHeldDown, button)
            elseif check_scan_code(this, keyboardState, 0, [scanCode[1]])
                if button in this.buttonsHeldDown
                    deleteat!(this.buttonsHeldDown, findfirst(x -> x == button, this.buttonsHeldDown))
                end
            end
        end
        this.buttonsPressedDown = buttonsPressedDown
    end

    function handle_mouse_event(this::Input, event)
        if event.button.button == SDL2.SDL_BUTTON_LEFT || event.button.button == SDL2.SDL_BUTTON_MIDDLE || event.button.button == SDL2.SDL_BUTTON_RIGHT
            button = event.button.button
            if event.type == SDL2.SDL_MOUSEBUTTONDOWN && !(button in this.mouseButtonsHeldDown)
                push!(this.mouseButtonsPressedDown, button)
                push!(this.mouseButtonsHeldDown, button)
            elseif event.type == SDL2.SDL_MOUSEBUTTONUP && (button in this.mouseButtonsHeldDown)
                push!(this.mouseButtonsReleased, button)
                deleteat!(this.mouseButtonsHeldDown, findfirst(x -> x == button, this.mouseButtonsHeldDown))
            end
        end
    end

    """
        handle_clipboard_paste()

    Handle Ctrl+V clipboard paste for images in the editor.
    Checks if clipboard contains image data and creates a temporary file for import.
    """
    function handle_clipboard_paste()
        try
            # Try to get image data from platform-specific clipboard
            if Sys.islinux()
                @debug "Linux detected, attempting to get image from X11 clipboard"
                handle_x11_clipboard_image()
            elseif Sys.isapple()
                @debug "macOS detected, attempting to get image from clipboard"
                handle_macos_clipboard_image()
            elseif Sys.iswindows()
                @debug "Windows detected, attempting to get image from clipboard"
                handle_windows_clipboard_image()
            end

            # Only check text clipboard if SDL reports it has text data
            # and avoid errors when clipboard contains binary data
            try
                if SDL2.SDL_HasClipboardText() == SDL2.SDL_TRUE
                    clipboard_text = unsafe_string(SDL2.SDL_GetClipboardText())

                    # Skip if the text looks like an error message from xclip
                    if occursin("xclip: Error:", clipboard_text) || occursin("ProcessFailedException", clipboard_text)
                        @debug "Skipping clipboard text that appears to be an error message"
                        return
                    end

                    @debug "Clipboard text: $(clipboard_text[1:min(100, length(clipboard_text))])"

                    # Check if it's a file path to an image
                    if isfile(clipboard_text) && is_image_file_by_extension(clipboard_text)
                        @debug "Clipboard contains image file path: $(clipboard_text)"
                        add_clipboard_file_to_import_queue(clipboard_text)
                        return
                    end

                    # Check if it's base64 image data (common format: data:image/png;base64,...)
                    if startswith(clipboard_text, "data:image/")
                        @debug "Clipboard contains base64 image data"
                        handle_base64_image_data(clipboard_text)
                        return
                    end
                end
            catch e
                @debug "Error reading text clipboard (likely contains binary data): $(e)"
            end

            # No additional fallback needed - platform-specific functions handle their own cases

        catch e
            @error "Error handling clipboard paste: $(e)"
        end
    end

    """
        handle_x11_clipboard_image()

    Try to get image data from X11 clipboard using xclip command.
    """
    function handle_x11_clipboard_image()
        try
            # Check if xclip is available
            if success(`which xclip`)
                @debug "xclip found, attempting to get image from clipboard"

                # Try to get PNG data from clipboard
                try
                    png_data = read(`xclip -selection clipboard -t image/png -o`)
                    if length(png_data) > 0
                        @debug "Found PNG data in clipboard"
                        # Create temporary file for PNG data
                        temp_file = tempname() * ".png"
                        open(temp_file, "w") do file
                            write(file, png_data)
                        end
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    end
                catch e
                    @debug "No PNG data in clipboard: $(e)"
                end

                # Try to get JPEG data from clipboard
                try
                    jpeg_data = read(`xclip -selection clipboard -t image/jpeg -o`)
                    if length(jpeg_data) > 0
                        @debug "Found JPEG data in clipboard"
                        # Create temporary file for JPEG data
                        temp_file = tempname() * ".jpg"
                        open(temp_file, "w") do file
                            write(file, jpeg_data)
                        end
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    end
                catch e
                    @debug "No JPEG data in clipboard: $(e)"
                end

                @debug "No image data found in X11 clipboard"
            else
                @debug "xclip not available, cannot access X11 clipboard"
            end
        catch e
            @warn "Error accessing X11 clipboard: $(e)"
        end
    end

    """
        handle_macos_clipboard_image()

    Try to get image data from macOS clipboard using pbpaste command.
    """
    function handle_macos_clipboard_image()
        try
            # Check if pbpaste is available (should be on all macOS systems)
            if success(`which pbpaste`)
                @debug "pbpaste found, attempting to get image from clipboard"

                # Try to get PNG data from clipboard
                try
                    png_data = read(`pbpaste -pboard general -Prefer png`)
                    if length(png_data) > 0
                        @debug "Found PNG data in clipboard"
                        # Create temporary file for PNG data
                        temp_file = tempname() * ".png"
                        open(temp_file, "w") do file
                            write(file, png_data)
                        end
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    end
                catch e
                    @debug "No PNG data in clipboard: $(e)"
                end

                # Try to get TIFF data from clipboard (common on macOS)
                try
                    tiff_data = read(`pbpaste -pboard general -Prefer tiff`)
                    if length(tiff_data) > 0
                        @debug "Found TIFF data in clipboard"
                        # Create temporary file for TIFF data
                        temp_file = tempname() * ".tiff"
                        open(temp_file, "w") do file
                            write(file, tiff_data)
                        end
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    end
                catch e
                    @debug "No TIFF data in clipboard: $(e)"
                end

                # Try to get JPEG data from clipboard
                try
                    jpeg_data = read(`pbpaste -pboard general -Prefer jpeg`)
                    if length(jpeg_data) > 0
                        @debug "Found JPEG data in clipboard"
                        # Create temporary file for JPEG data
                        temp_file = tempname() * ".jpg"
                        open(temp_file, "w") do file
                            write(file, jpeg_data)
                        end
                        add_clipboard_file_to_import_queue(temp_file)
                        return
                    end
                catch e
                    @debug "No JPEG data in clipboard: $(e)"
                end

                @debug "No image data found in macOS clipboard"
            else
                @debug "pbpaste not available, cannot access macOS clipboard"
            end
        catch e
            @warn "Error accessing macOS clipboard: $(e)"
        end
    end

    """
        handle_windows_clipboard_image()

    Try to get image data from Windows clipboard using PowerShell.
    """
    function handle_windows_clipboard_image()
        try
            @debug "Attempting to get image from Windows clipboard using PowerShell"

            # PowerShell script to get image from clipboard and save as PNG
            powershell_script = """
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
            \$clipboard = [System.Windows.Forms.Clipboard]::GetImage()
            if (\$clipboard -ne \$null) {
                \$temp_file = [System.IO.Path]::GetTempFileName() + ".png"
                \$clipboard.Save(\$temp_file, [System.Drawing.Imaging.ImageFormat]::Png)
                Write-Output \$temp_file
            }
            """

            try
                # Run PowerShell script
                result = readchomp(`powershell -Command "$powershell_script"`)
                if !isempty(result) && isfile(result)
                    @debug "Found image data in Windows clipboard, saved to: $(result)"
                    add_clipboard_file_to_import_queue(result)
                    return
                end
            catch e
                @debug "No image data in Windows clipboard: $(e)"
            end

            @debug "No image data found in Windows clipboard"
        catch e
            @warn "Error accessing Windows clipboard: $(e)"
        end
    end

    """
        is_image_file_by_extension(filepath::String) -> Bool

    Check if file has an image extension.
    """
    function is_image_file_by_extension(filepath::String)
        ext = lowercase(splitext(filepath)[2])
        return ext in [".png", ".jpg", ".jpeg", ".bmp", ".tga", ".gif", ".webp"]
    end

    """
        add_clipboard_file_to_import_queue(filepath::String)

    Add a clipboard file path to the import queue.
    """
    function add_clipboard_file_to_import_queue(filepath::String)
        dropped_files = "dropped_files"
        if get(JulGame.EditorState, dropped_files, nothing) === nothing
            JulGame.EditorState[dropped_files] = [filepath]
        else
            push!(JulGame.EditorState[dropped_files], filepath)
        end
        @debug "Added clipboard file to import queue: $(basename(filepath))"
    end

    """
        handle_base64_image_data(data::String)

    Handle base64 encoded image data from clipboard.
    Creates a temporary file and adds it to the import queue.
    """
    function handle_base64_image_data(data::String)
        try
            # Parse the data URL format: data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...
            if !occursin(";base64,", data)
                @warn "Invalid base64 image data format"
                return
            end

            # Extract MIME type and base64 data
            parts = split(data, ";base64,")
            if length(parts) != 2
                @warn "Invalid base64 image data format"
                return
            end

            mime_part = parts[1]
            base64_data = parts[2]

            # Determine file extension from MIME type
            extension = ".png"  # default
            if occursin("image/jpeg", mime_part) || occursin("image/jpg", mime_part)
                extension = ".jpg"
            elseif occursin("image/png", mime_part)
                extension = ".png"
            elseif occursin("image/gif", mime_part)
                extension = ".gif"
            elseif occursin("image/bmp", mime_part)
                extension = ".bmp"
            elseif occursin("image/webp", mime_part)
                extension = ".webp"
            end

            # Create temporary file
            temp_dir = mktempdir()
            timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
            temp_filename = "clipboard_image_$(timestamp)$(extension)"
            temp_filepath = joinpath(temp_dir, temp_filename)

            # Decode base64 and write to file
            image_data = Base64.base64decode(base64_data)
            write(temp_filepath, image_data)

            @debug "Created temporary image file from clipboard: $(temp_filepath)"

            # Add to import queue
            add_clipboard_file_to_import_queue(temp_filepath)

        catch e
            @error "Error processing base64 image data: $(e)"
        end
    end

    function update_input_state(this::Input, data::Dict{String, Any})
        this.buttonsHeldDown = [key for (key, value) in data if value]
    end

    function get_button_held_down(this::Input, button::String)
        if uppercase(button) in this.buttonsHeldDown
            return true
        end
        return false
    end

    function get_button_held_down(button::String)
        return get_button_held_down(MAIN.input, button)
    end

    function get_button_pressed(button::String)
        return get_button_pressed(MAIN.input, button)
    end

    function get_button_pressed(this::Input, button::String)
        if uppercase(button) in this.buttonsPressedDown
            return true
        end
        return false
    end

    function get_button_released(button::String)
        return get_button_released(MAIN.input, button)
    end

    function get_button_released(this::Input, button::String)
        if uppercase(button) in this.buttonsReleased
            return true
        end
        return false
    end

    function get_mouse_button(this::Input, button::Any)
        if button in this.mouseButtonsHeldDown
            return true
        end
        return false
    end

    function get_mouse_button(button::Any)
        return get_mouse_button(MAIN.input, button)
    end

    function get_mouse_button_pressed(this::Input, button::Any)
        if button in this.mouseButtonsPressedDown
            return true
        end
        return false
    end

    function get_mouse_button_pressed(button::Any)
        return get_mouse_button_pressed(MAIN.input, button)
    end

    function get_mouse_button_released(this::Input, button::Any)
        if button in this.mouseButtonsReleased
            return true
        end
        return false
    end

    function get_mouse_button_released(button::Any)
        return get_mouse_button_released(MAIN.input, button)
    end

    function get_mouse_position(this::Input)
        return this.mousePosition
    end

    function get_mouse_position()
        return get_mouse_position(MAIN.input)
    end

    function get_mouse_position_in_world_space(this::Input)
        return this.mousePositionWorld
    end

    function get_mouse_position_in_world_space()
        return get_mouse_position_in_world_space(MAIN.input)
    end

    function create_cursor_bank(this::Input)
        this.cursorBank["arrow"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_ARROW)
        this.cursorBank["ibeam"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_IBEAM)
        this.cursorBank["wait"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_WAIT)
        this.cursorBank["crosshair"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_CROSSHAIR)
        this.cursorBank["waitarrow"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_WAITARROW)
        this.cursorBank["sizeall"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZEALL)
        this.cursorBank["sizenesw"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENESW)
        this.cursorBank["sizenwse"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENWSE)
        this.cursorBank["sizewe"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZEWE)
        this.cursorBank["sizens"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_SIZENS)
        this.cursorBank["no"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_NO)
        this.cursorBank["hand"] = SDL2.SDL_CreateSystemCursor(SDL2.SDL_SYSTEM_CURSOR_HAND)
    end

    # Initialize an SDL_Event instance
    function init_sdl_event()::Ptr{SDL2.SDL_Event}
        # Create a vector of UInt8
        data = UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

         # Convert the vector to a tuple of size 56
        ntuple_data = Tuple(data)

        # Allocate memory for the SDL_Event struct itself
        ptr_event = Ptr{SDL2.SDL_Event}(Libc.malloc(sizeof(SDL2.SDL_Event)))  # Allocate memory for SDL_Event struct

        # Now, initialize the data field of the struct using unsafe_store!
        unsafe_store!(ptr_event, SDL2.SDL_Event(ntuple_data))

        # Return the pointer to the struct
        return ptr_event
    end

    function init_mouse_button_event()::Ptr{SDL2.SDL_MouseButtonEvent}
        # Allocate memory for SDL_MouseButtonEvent struct
        ptr_event = Ptr{SDL2.SDL_MouseButtonEvent}(Libc.malloc(sizeof(SDL2.SDL_MouseButtonEvent)))

        # Initialize the fields directly
        unsafe_store!(ptr_event, SDL2.SDL_MouseButtonEvent(
            0x0,             # type (just an example, you'll set this later)
            0x0,             # timestamp
            0x0,             # windowID
            0x0,             # which (mouse)
            0x0,             # button (mouse button)
            0x0,             # state (pressed/released)
            0x0,             # clicks
            0x0,             # padding
            0x0,             # x (position)
            0x0              # y (position)
        ))

        # Return the pointer to the struct
        return ptr_event
    end

    function simulate_mouse_click(this::Input, window::Ptr{SDL2.SDL_Window}, x::Number, y::Number)
        # Get current window size
        window_width = Ref{Cint}(0)
        window_height = Ref{Cint}(0)
        SDL2.SDL_GetWindowSize(window, window_width, window_height)

        # Get base resolution from WindowManager
        logical_size = JulGame.WindowManagerModule.get_logical_size()

        safe_window_width = max(window_width[], 1)
        safe_window_height = max(window_height[], 1)
        safe_logical_width = max(logical_size.x, 1)
        safe_logical_height = max(logical_size.y, 1)
        scale_x = safe_window_width / safe_logical_width
        scale_y = safe_window_height / safe_logical_height
        scale = min(scale_x, scale_y)
        content_width = safe_logical_width * scale
        content_height = safe_logical_height * scale
        bar_x = (safe_window_width - content_width) / 2
        bar_y = (safe_window_height - content_height) / 2

        # Convert logical coordinates to window coordinates (inverse of poll_input mapping)
        window_x = round(Int, (x * scale) + bar_x)
        window_y = round(Int, (y * scale) + bar_y)
        x = Math.TypeConversions.safe_int32_convert(window_x)
        y = Math.TypeConversions.safe_int32_convert(window_y)
        # Move the mouse to the specified position
        @debug "Moving mouse to $(x), $(y)"
        SDL2.SDL_WarpMouseInWindow(window, x, y)

        # Create a mouse button down event
        mouse_event::Ptr{SDL2.SDL_Event} = init_sdl_event()
        mouse_event.type = SDL2.SDL_MOUSEBUTTONDOWN

        mouse_event.button = SDL2.SDL_MouseButtonEvent(
            SDL2.SDL_MOUSEBUTTONDOWN,  # Type of event
            0,                        # Timestamp (0 for automatic)
            0,                        # Window ID (0 for default window)
            0,                        # Which mouse (0 for the primary mouse)
            SDL2.SDL_BUTTON_LEFT,      # Button being pressed
            SDL2.SDL_PRESSED,          # Button state (pressed)
            1,                         # Clicks (1 for single click)
            0,                         # Padding (unused, set to 0)
            x,                         # X position
            y                          # Y position
        )
        SDL2.SDL_PushEvent(mouse_event)
        
        # Immediately push button up event as well so both are processed together
        # This is especially important when window isn't focused
        mouse_up_event::Ptr{SDL2.SDL_Event} = init_sdl_event()
        mouse_up_event.type = SDL2.SDL_MOUSEBUTTONUP
        mouse_up_event.button = SDL2.SDL_MouseButtonEvent(
            SDL2.SDL_MOUSEBUTTONUP,  # Type of event
            0,                        # Timestamp (0 for automatic)
            0,                        # Window ID (0 for default window)
            0,                        # Which mouse (0 for the primary mouse)
            SDL2.SDL_BUTTON_LEFT,      # Button being pressed
            SDL2.SDL_RELEASED,         # Button state (released)
            1,                         # Clicks (1 for single click)
            0,                         # Padding (unused, set to 0)
            x,                         # X position (same as button down)
            y                          # Y position (same as button down)
        )
        SDL2.SDL_PushEvent(mouse_up_event)
        
        this.isTestButtonClicked = false  # No need to lift later since we pushed it immediately
        this.simulatedClickPosition = nothing
    end

    function simulate_mouse_click(x::Number, y::Number)
        simulate_mouse_click(MAIN.input, MAIN.windowManager.window, x, y)
    end

    function lift_mouse_after_simulated_click(this)
        # Use the stored click position, or current mouse position as fallback
        if this.simulatedClickPosition !== nothing
            click_x = Int32(this.simulatedClickPosition.x)
            click_y = Int32(this.simulatedClickPosition.y)
        else
            # Fallback to current mouse position
            x_ref, y_ref = Ref{Cint}(0), Ref{Cint}(0)
            SDL2.SDL_GetMouseState(x_ref, y_ref)
            click_x = Int32(x_ref[])
            click_y = Int32(y_ref[])
        end
        
        mouse_event::Ptr{SDL2.SDL_Event} = init_sdl_event()
        mouse_event.type = SDL2.SDL_MOUSEBUTTONUP
        mouse_event.button = SDL2.SDL_MouseButtonEvent(
            SDL2.SDL_MOUSEBUTTONUP,  # Type of event
            0,                        # Timestamp (0 for automatic)
            0,                        # Window ID (0 for default window)
            0,                        # Which mouse (0 for the primary mouse)
            SDL2.SDL_BUTTON_LEFT,      # Button being pressed
            SDL2.SDL_RELEASED,          # Button state (released)
            1,                         # Clicks (1 for single click)
            0,                         # Padding (unused, set to 0)
            click_x,                   # X position (same as button down)
            click_y                    # Y position (same as button down)
        )
        SDL2.SDL_PushEvent(mouse_event)
        this.isTestButtonClicked = false
        this.simulatedClickPosition = nothing
    end

    function lift_mouse_after_simulated_click()
        lift_mouse_after_simulated_click(MAIN.input)
    end

    function simulate_key_press(this::Input, key::String)
        # Create a keyboard event
        key_event::Ptr{SDL2.SDL_Event} = init_sdl_event()
        key_event.type = SDL2.SDL_KEYDOWN
        key_event.key = SDL2.SDL_KeyboardEvent(
            SDL2.SDL_KEYDOWN,  # Type of event
            0,                 # Timestamp (0 for automatic)
            0,                 # Window ID (0 for default window)
            0,                 # State (pressed)
            0,                 # Repeat (0 for no repeat)
            0,                 # Padding
            0,                 # Padding
            SDL2.SDL_Keysym(   # Keysym structure
                SDL2.SDL_SCANCODE_SPACE, # Scancode
                0,  # Keycode
                0,                                   # Modifiers (none)
                0                                    # Window ID (0 for default window)
            )
        )
        # key_event.key.keysym.sym = SDL2.SDL_Keycode(uppercase(key))
        # key_event.key.keysym.scancode = SDL2.SDL_Scancode(uppercase(key))
        # key_event.key.keysym.mod = 0
        # key_event.key.keysym.windowID = 0

        # Push the event to the event queue
        SDL2.SDL_PushEvent(key_event)
    end

    function simulate_key_press(key::String)
        simulate_key_press(MAIN.input, key)
    end

    function get_comma_separated_path(path::String)
        # Normalize the path to use forward slashes
        normalized_path = replace(path, '\\' => '/')

        # Split the path into components
        parts = split(normalized_path, '/')

        result = join(parts[1:end], ",")

        return result
    end

    """
        set_cursor_with_image(this, imagePath, x, y, scale_factor)

        Loads an image as an SDL cursor, applies a scaling factor, and updates the hotspot position.

        # Arguments
        - `this::Input`: The input object storing the cursor reference.
        - `imagePath::String`: Path to the image file.
        - `x::Int, y::Int`: Original hotspot position in the image.
        - `scale_factor::Float64`: Scaling factor for resizing the cursor (default = 1.0).

        # Example
        set_cursor_with_image(this, "cursor.png", 10, 10, 2.0)  # Scales up by 2x
    """
    function set_cursor_with_image(this::Input, imagePath::String, x::Int, y::Int, scale_factor::Float64=1.0)
        surface = nothing
        if haskey(JulGame.IMAGE_CACHE, get_comma_separated_path(imagePath))
            raw_data = JulGame.IMAGE_CACHE[get_comma_separated_path(imagePath)]
            rw = SDL2.SDL_RWFromConstMem(pointer(raw_data), length(raw_data))
            if rw != C_NULL
                @debug("loading cursor from cache")
                @debug("comma separated path: ", get_comma_separated_path(imagePath))
                surface = SDL2.IMG_Load_RW(rw, 1)
            end
        else
            @debug("loading cursor from disk")
            surface = SDL2.IMG_Load(pointer(joinpath(JulGame.BasePath, "assets", "images", imagePath)))
        end
        @debug "Loading image from disk $(fullPath) for sprite, there are $(length(JulGame.IMAGE_CACHE)) images in cache"

        if surface == C_NULL
            @error "Failed to load cursor image: $(unsafe_string(SDL2.SDL_GetError()))"
            return
        end

        # Get original width and height
        original_width = unsafe_load(surface).w
        original_height = unsafe_load(surface).h

        # Calculate new dimensions
        new_width = Int(round(original_width * scale_factor))
        new_height = Int(round(original_height * scale_factor))

        # Scale the hotspot position
        new_x = Int(round(x * scale_factor))
        new_y = Int(round(y * scale_factor))

        # Create a new surface for the scaled image
        scaled_surface = SDL2.SDL_CreateRGBSurface(0, new_width, new_height, 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)

        if scaled_surface == C_NULL
            @error "Failed to create scaled surface: $(unsafe_string(SDL2.SDL_GetError()))"
            SDL2.SDL_FreeSurface(surface)
            return
        end

        # Scale the image onto the new surface
        SDL2.SDL_BlitScaled(surface, C_NULL, scaled_surface, C_NULL)

        # Create cursor from the scaled surface with adjusted hotspot
        cursor = SDL2.SDL_CreateColorCursor(scaled_surface, new_x, new_y)

        if cursor != C_NULL
            set_cursor(cursor)
            this.defaultCursor = cursor
            @debug "Cursor set successfully! Scaled by $(scale_factor)x, Hotspot: ($new_x, $new_y)"
        else
            @error "Issue loading cursor: $(unsafe_string(SDL2.SDL_GetError()))"
        end

        # Free surfaces to avoid memory leaks
        SDL2.SDL_FreeSurface(surface)
        SDL2.SDL_FreeSurface(scaled_surface)

        return cursor
    end

    function set_cursor_with_image(imagePath::String, x::Int, y::Int, scale_factor::Float64=1.0)
        set_cursor_with_image(MAIN.input, imagePath, x, y, scale_factor)
    end

    function set_cursor(cursor)
        SDL2.SDL_SetCursor(cursor)
    end

    """
    collect_canvas_children(canvas::UI.Canvas, allElements::Vector{UI.UIElement})

    Recursively collects all children of a canvas and its sub-canvases.
    """
    # function collect_canvas_children(canvas::UI.Canvas, allElements::Vector{UI.UIElement})
    #     for child in canvas.children
    #         push!(allElements, child)
    #         # If the child is also a canvas, collect its children recursively
    #         if isa(child, UI.Canvas)
    #             collect_canvas_children(child, allElements)
    #         end
    #     end
    # end
end # module InputModule
