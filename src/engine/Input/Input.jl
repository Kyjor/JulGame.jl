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
        mouseButtonsPressedDown
        mouseButtonsHeldDown
        mouseButtonsReleased
        mousePosition
        mousePositionEditorGameWindowOffset::Vector2
        mousePositionWorld::Math.Vector2f
        joystick
        scanCodeStrings::Vector{String}
        scanCodes
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
                if codeString == "SDL_NUM_SCANCODES"
                    continue
                end
                # Keep scanCodes as plain numeric ids + string names (TS doesn't have a native SDL enum type).
                push!(this.scanCodes, [Int32(m), SubString(codeString, 14, length(codeString))])
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

    include("api.jl")
    include("clipboard.jl")
    include("cursor.jl")
    include("profile.jl")
    include("test_helpers.jl")
    include("ui.jl")

    function _refresh_logical_mouse!(this::Input, evt::SDL2.SDL_Event)
        x = Int32[1]
        y = Int32[1]
        SDL2.SDL_GetMouseState(pointer(x), pointer(y))

        window_focused = false
        if evt.type == SDL2.SDL_MOUSEBUTTONDOWN || evt.type == SDL2.SDL_MOUSEBUTTONUP
            @debug "Mouse down: $(evt.type == SDL2.SDL_MOUSEBUTTONDOWN)"
            @debug "mouse state: $(x[1]), $(y[1])"
            window_focused = (JulGame.MAIN !== nothing && JulGame.MAIN.windowManager !== nothing && JulGame.MAIN.windowManager.isWindowFocused)
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

        scale_x = 0
        scale_y = 0
        scaled_x = 0
        scaled_y = 0
        if !JulGame.IS_EDITOR
            window_width = Ref{Cint}(0)
            window_height = Ref{Cint}(0)
            SDL2.SDL_GetWindowSize(JulGame.MAIN.windowManager.window, window_width, window_height)
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
                @error("Mouse position is infinite")
                scaled_x = 0
                scaled_y = 0
            end
            window_focused = (JulGame.MAIN !== nothing && JulGame.MAIN.windowManager !== nothing && JulGame.MAIN.windowManager.isWindowFocused)
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
            camera_size = JulGame.MAIN.scene.camera.size
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
    # Cached: this is called from the per-element hit-test hot path, and an ENV
    # read allocates and is slow (it was happening hundreds of times per mouse event)
    const _trace_input_ui_hit_ref = Ref{Union{Nothing, Bool}}(nothing)
    function _input_ui_hit_stream_logs()
        v = _trace_input_ui_hit_ref[]
        if v === nothing
            e = lowercase(strip(get(ENV, "JULGAME_TRACE_INPUT_UI_HIT", "")))
            _trace_input_ui_hit_ref[] = e in ("1", "true", "yes", "on")
        end
        return _trace_input_ui_hit_ref[]::Bool
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
        if prof === nothing && !_input_ui_hit_stream_logs()
            return
        end
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
        if prof === nothing && !_input_ui_hit_stream_logs()
            return
        end
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

    # Reused hit-test buffers: rebuilding these per mouse event with
    # filter/reverse/sort/vcat was allocating several KB per event (mouse motion
    # happens every frame), creating GC pressure that shows up as frame dips.
    const _hitTestCandidates = Any[]
    const _inactiveCanvasChildren = Set{Any}()

    # Build the layer-descending hit-test candidate list into the reused
    # buffers, paring out elements that can never receive input (inactive,
    # ignoring input, spriteless entities, children of inactive canvases) so
    # they are neither sorted nor iterated.
    # Elements are pushed in reverse scene order to preserve the previous
    # reverse + stable-sort tie-break (later elements win within a layer).
    function _build_hit_test_candidates!()
        empty!(_inactiveCanvasChildren)
        uiElements = MAIN.scene.uiElements
        for ui in uiElements
            if isa(ui, JulGame.ICanvas) && !ui.isActive
                for child in ui.children
                    push!(_inactiveCanvasChildren, child)
                end
            end
        end

        candidates = _hitTestCandidates
        empty!(candidates)
        for i in length(uiElements):-1:1
            ui = uiElements[i]
            if ui.isActive && !(ui in _inactiveCanvasChildren)
                push!(candidates, ui)
            end
        end
        nUI = length(candidates)
        sort!(view(candidates, 1:nUI), by = uiElement -> uiElement.layer, rev = true)

        entities = MAIN.scene.entities
        for i in length(entities):-1:1
            entity = entities[i]
            if entity.isActive && !entity.ignoreInputEvents &&
               entity.sprite !== nothing && entity.sprite !== C_NULL &&
               !(entity in _inactiveCanvasChildren)
                push!(candidates, entity)
            end
        end
        if length(candidates) > nUI
            sort!(view(candidates, nUI+1:length(candidates)), by = entity -> entity.sprite.layer, rev = true)
        end
        return candidates, nUI
    end

    function poll_input(this::Input)
        # prof = _input_latency_profiler()
        # t0 = Ref(time_ns())

        empty!(this.buttonsPressedDown)
        empty!(this.mouseButtonsPressedDown)
        empty!(this.mouseButtonsReleased)  # Clear the released buttons each frame
        this.didMouseEventOccur = false
        this.didMouseMotionOccur = false
        event_ref = Ref{SDL2.SDL_Event}()

        while true
            if length(this.pending_sdl_events) > 0
                event_ref[] = popfirst!(this.pending_sdl_events)
            elseif SDL2.SDL_PollEvent(event_ref) == 0
                break
            end
            # _input_poll_accumulate!(prof, t0, :sdl_PollEvent)

            evt = event_ref[]
            handle_window_events(this, evt)

            # @debug "polling input"
            # Only update mouse position for mouse-related events
            if evt.type == SDL2.SDL_MOUSEMOTION || evt.type == SDL2.SDL_MOUSEBUTTONDOWN || evt.type == SDL2.SDL_MOUSEBUTTONUP
                _refresh_logical_mouse!(this, evt)
                if evt.type == SDL2.SDL_MOUSEMOTION
                    coalesce_ref = Ref{SDL2.SDL_Event}()
                    lastMotionEvent = nothing
                    while Bool(SDL2.SDL_PollEvent(coalesce_ref))
                        e2 = coalesce_ref[]
                        if e2.type == SDL2.SDL_MOUSEMOTION
                            lastMotionEvent = e2
                            this.didMouseMotionOccur = true
                        else
                            push!(this.pending_sdl_events, e2)
                        end
                    end
                    # Refresh once for the newest motion; the intermediate
                    # positions were overwritten anyway and the refresh does
                    # window-size + letterbox math per call
                    if lastMotionEvent !== nothing
                        _refresh_logical_mouse!(this, lastMotionEvent)
                    end
                end
            end

            if this.editorCallback !== nothing
                this.editorCallback(evt)
            end

            
            _handle_dropped_files(this, evt)
            _handle_clipboard_paste(this, evt)

            # _input_poll_accumulate!(prof, t0, :window_routing)

            if evt.type == SDL2.SDL_MOUSEMOTION || evt.type == SDL2.SDL_MOUSEBUTTONDOWN || evt.type == SDL2.SDL_MOUSEBUTTONUP
                t_ms_blk = time_ns()
                this.didMouseEventOccur = true
                if evt.type == SDL2.SDL_MOUSEMOTION
                    this.didMouseMotionOccur = true
                end
                if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
                    @debug("Mouse button down at $(this.mousePosition)")
                end

                ui_hit_active = JulGame.MAIN.scene.uiElements !== nothing && !(JulGame.IS_EDITOR && !JulGame.MAIN.isGameModeRunningInEditor)
                if ui_hit_active
                    # _input_ui_hit_span!(prof, t_ms_blk, :hit_mouse_evt_preamble)
                    t_ui_wall = time_ns()
                    t_hit = Ref(time_ns())
                    # _input_ui_hit_step!(prof, t_hit, :hit_ui_enter; evt = evt.type, mouse = (this.mousePosition.x, this.mousePosition.y), n_ui = length(MAIN.scene.uiElements))
                    if JulGame.MAIN.scene.camera === nothing
                        # _input_ui_hit_step!(prof, t_hit, :hit_ui_abort_camera)
                        @warn ("Camera is not set in the main scene.")
                        # _input_poll_accumulate!(prof, t0, :mouse_ui_aborted_no_camera)
                        continue
                    end
                    # _input_ui_hit_step!(prof, t_hit, :hit_ui_camera_ok)

                    # Pared + sorted into reused buffers; see _build_hit_test_candidates!
                    elementsOrderedByLayerDescending, nUICandidates = _build_hit_test_candidates!()
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_filter_canvas; n_hidden = length(_inactiveCanvasChildren))
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_sort_ui; n = nUICandidates)
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_sort_entities; n = length(elementsOrderedByLayerDescending) - nUICandidates, n_entities = length(MAIN.scene.entities))
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_vcat; n_total = length(elementsOrderedByLayerDescending))

                    # TODO: add rest of entities without sprites in default order
                    # restOfEntities = filter(entity -> entity.sprite === nothing || entity.sprite === C_NULL, JulGame.MAIN.scene.entities)
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
                        # Re-check here (despite build-time paring) because a click
                        # handler earlier in this loop can deactivate a canvas
                        if !skipElement && element in _inactiveCanvasChildren
                            skipElement = true
                            n_skipped_canvas += 1
                        end
                        if isa(element, JulGame.IEntity) && element.ignoreInputEvents
                            skipElement = true
                            if element.isActive
                                n_skipped_ignore += 1
                            end
                        end

                        if skipElement
                            @debug "Skipping element $(element.name) - isActive: $(element.isActive)"
                            # _input_ui_hit_span!(prof, t_iter, :hit_ui_iter_skip_early)
                            continue
                        end

                        # _input_ui_hit_span!(prof, t_iter, :hit_ui_iter_probe_active_filter)
                        t_prep0 = time_ns()

                        # Check position of button to see which we are interacting with
                        eventWasInsideThisElement = true

                        mouseX = this.mousePosition.x
                        mouseY = this.mousePosition.y

                        # _input_ui_hit_span!(prof, t_prep0, :hit_ui_iter_probe_prep_hitbox)
                        t_geom0 = time_ns()

                        # UI Element position and size in screen space (MUST BE SCALED)
                        elementPosition = get_element_position(element)
                        # _input_ui_hit_span!(prof, t_geom0, :hit_ui_iter_probe_get_position)
                        t_sz0 = time_ns()

                        elementSize = get_element_size(element)
                        # _input_ui_hit_span!(prof, t_sz0, :hit_ui_iter_probe_get_size)
                        t_unpk0 = time_ns()

                        screenElementX = elementPosition.x
                        screenElementY = elementPosition.y
                        screenElementWidth = elementSize.x
                        screenElementHeight = elementSize.y

                        @debug "Checking element '$(element.name)': mouse($mouseX, $mouseY) vs element($screenElementX, $screenElementY, $screenElementWidth, $screenElementHeight)"

                        # Check if the mouse is inside the UI element (using game world coordinates)
                        # _input_ui_hit_span!(prof, t_unpk0, :hit_ui_iter_probe_unpack_layout)
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
                        # _input_ui_hit_span!(prof, t_aabb, :hit_ui_iter_probe_aabb)

                        if !eventWasInsideThisElement
                            element.isHovered = false
                            t_ctr = time_ns()
                            n_miss_bounds += 1
                            # _input_ui_hit_span!(prof, t_ctr, :hit_ui_iter_miss_hover_counter_inc)
                            continue
                        end

                        n_hit_inside += 1
                        t_hi = time_ns()
                        @debug "  -> Mouse is INSIDE element '$(element.name)'"

                        clicked_down_here = clicked_down_on_this_element(this, element)
                        # _input_ui_hit_span!(prof, t_hi, :hit_inside_1_clicked_down_query)
                        t_hi = time_ns()

                        canClickOnThisElement = (!clickedAnElementAlready || element.forceClickCheck) && clicked_down_here
                        @debug "  -> canClickOnThisElement: $canClickOnThisElement, clickedAnElementAlready: $clickedAnElementAlready, forceClickCheck: $(element.forceClickCheck), clicked_down_on_this_element: $clicked_down_here"
                        # _input_ui_hit_span!(prof, t_hi, :hit_inside_2_can_click_bools)
                        t_hi = time_ns()

                        if !clickedAnElementAlready || element.forceClickCheck
                            shouldHandleEvent = (!hoveredAnElementAlready && evt.type == SDL2.SDL_MOUSEMOTION) ||
                                (element.forceClickCheck && evt.type == SDL2.SDL_MOUSEMOTION) ||
                                (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && !clickedAnElementAlready) ||
                                (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && element.forceClickCheck) ||
                                (canClickOnThisElement && evt.type == SDL2.SDL_MOUSEBUTTONUP)

                            @debug "  -> shouldHandleEvent: $shouldHandleEvent (event type: $(evt.type), hoveredAnElementAlready: $hoveredAnElementAlready)"
                            # _input_ui_hit_span!(prof, t_hi, :hit_inside_3a_should_handle_expr)
                            t_hi = time_ns()

                            if shouldHandleEvent
                                #@debug "  -> Handling event for element '$(element.name)'"
                                JulGame.UI.handle_event(element, evt, this.mousePosition.x, this.mousePosition.y)
                                t_hi = time_ns()
                                if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
                                   push!(this.elementsBeingClickedDownOn, element)
                                   @debug "  -> Added '$(element.name)' to elementsBeingClickedDownOn"
                                end
                                # _input_ui_hit_span!(prof, t_hi, :hit_inside_5_push_clicked_down_optional)
                                t_hi = time_ns()
                            else
                                # _input_ui_hit_span!(prof, t_hi, :hit_inside_4_skip_should_handle_false)
                                t_hi = time_ns()
                            end
                            if element.isHovered
                                hoveredAnElementAlready = true
                            end
                            # _input_ui_hit_span!(prof, t_hi, :hit_inside_6_hover_an_element_already)
                            t_hi = time_ns()
                        else
                            # _input_ui_hit_span!(prof, t_hi, :hit_inside_3b_skip_clicked_guard)
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
                        # _input_ui_hit_span!(prof, t_hi, :hit_inside_7_mouse_btn_tail)
                    end
                    t_tail = Ref(time_ns())
                    if evt.type == SDL2.SDL_MOUSEBUTTONUP
                        this.elementsBeingClickedDownOn = []
                        # _input_ui_hit_step!(prof, t_tail, :hit_ui_clear_click_state)
                    end
                    # _input_ui_hit_step!(prof, t_tail, :hit_ui_block_end)
                    # _input_ui_hit_span!(prof, t_ui_wall, :hit_ui_block_wall_clock)
                else
                    # _input_ui_hit_span!(prof, t_ms_blk, :hit_mouse_evt_skip_ui_hit_path)
                end

                t_hm = time_ns()
                handle_mouse_event(this, evt)
                # _input_ui_hit_span!(prof, t_hm, :hit_mouse_evt_handle_mouse_event)
            end

            #_input_poll_accumulate!(prof, t0, :mouse_ui_hit_test_dispatch)

                # if evt.jaxis.which == 0
                #     this.jaxis = evt.jaxis
                # end
                # for i in 0:this.numAxes-1
                #     axis = SDL2.SDL_JoystickGetAxis(this.joystick, i)
                #     if i < 0
                #         @debug("Axis $i: $(SDL2.SDL_JoystickGetAxis(this.joystick, i))")
                #     end
                #     JOYSTICK_DEAD_ZONE = 8000

                #     if i == 0
                #         if axis < -JOYSTICK_DEAD_ZONE
                #             this.xDir = -1
                #         # Right of dead zone
                #         elseif axis > JOYSTICK_DEAD_ZONE
                #             this.xDir = 1
                #         else
                #             this.xDir = 0
                #         end
                #     elseif i == 1
                #         if axis < -JOYSTICK_DEAD_ZONE
                #             this.yDir = -1
                #         # Right of dead zone
                #         elseif axis > JOYSTICK_DEAD_ZONE
                #             this.yDir = 1
                #         else
                #             this.yDir = 0
                #         end
                #     end

                # end

                # for i in 0:this.numButtons-1
                #     button = SDL2.SDL_JoystickGetButton(this.joystick, i)

                #     if button != 0
                #         @debug("Button $i: $(button)")
                #     end
                #     if i == 0 && button == 1
                #         this.button = 1
                #     elseif i == 0
                #         this.button = 0
                #     end
                # end

                # for i in 0:this.numHats-1

                #     hat = SDL2.SDL_JoystickGetHat(this.joystick, i)
                #     if hat != 0
                #         @debug("Hat $i: $(hat)")
                #     end
                # end
            if evt.type == SDL2.SDL_QUIT
                this.quit = true
                #_input_poll_accumulate!(prof, t0, :joystick_keyboard_state)
                return -1
            end
            if evt.type == SDL2.SDL_KEYDOWN && evt.key.keysym.scancode == SDL2.SDL_SCANCODE_F3
                this.debug = !this.debug
                JulGame.IS_DEBUG = !JulGame.IS_DEBUG
            end

            # Keyboard state only changes on key events; scanning ~300 scancodes
            # for every mouse-motion event was wasted work
            if evt.type == SDL2.SDL_KEYDOWN || evt.type == SDL2.SDL_KEYUP
                keyboardState = unsafe_wrap(Array, SDL2.SDL_GetKeyboardState(C_NULL), 300; own = false)
                handle_key_event(this, keyboardState)
            end

            #_input_poll_accumulate!(prof, t0, :joystick_keyboard_state)
        end

        # if this.isTestButtonClicked
        #     lift_mouse_after_simulated_click(this)
        # end
    end

    function check_scan_code(this::Input, keyboardState, keyState, scanCodes)
        for scanCode in scanCodes
            try
                check_code = Int32(scanCode) + 1
                if keyboardState[check_code] == keyState
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
            if check_scan_code(this, keyboardState, 1, (scanCode[1],)) && !(button in this.buttonsHeldDown)
                push!(buttonsPressedDown, button)
                push!(this.buttonsHeldDown, button)
            elseif check_scan_code(this, keyboardState, 0, (scanCode[1],))
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
end # module InputModule
