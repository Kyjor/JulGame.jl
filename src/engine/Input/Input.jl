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
        editorCallback::Union{Nothing, JulGame.AbstractEditorSDLEventSink}
        main
        mouseButtonsPressedDown::Vector{UInt8}
        mouseButtonsHeldDown::Vector{UInt8}
        mouseButtonsReleased::Vector{UInt8}
        mousePosition::JulGame.Math.Vector2
        mousePositionEditorGameWindowOffset::JulGame.Math.Vector2
        mousePositionWorld::JulGame.Math.Vector2f
        joystick::Ptr{SDL2.SDL_Joystick}
        scanCodeStrings::Vector{String}
        scanCodes::Vector{Tuple{SDL2.SDL_Scancode, SubString{String}}}
        quit::Bool

        elementsBeingClickedDownOn::Vector{Union{JulGame.IUIElement, JulGame.IEntity}}

        #Gamepad
        jaxis
        xDir::Int
        yDir::Int
        numAxes::Int
        numButtons::Int
        numHats::Int
        button::Int

        # Cursor bank
        cursorBank::Dict{String, Ptr{SDL2.SDL_SystemCursor}} # Key is the name of the cursor, value is the SDL2 cursor

        # Testing
        isTestButtonClicked::Bool
        simulatedClickPosition::Union{JulGame.Math.Vector2, Nothing}

        # SDL events pulled while coalescing SDL_MOUSEMOTION (processed on following poll_input iterations)
        pending_sdl_events::Vector{SDL2.SDL_Event}

        function Input()
            this = new()

            this.buttonsPressedDown = String[]
            this.buttonsHeldDown = String[]
            this.buttonsReleased = String[]
            this.debug = false
            this.didMouseEventOccur = false
            this.didMouseMotionOccur = false
            this.editorCallback = nothing
            this.mouseButtonsPressedDown = UInt8[]
            this.mouseButtonsHeldDown = UInt8[]
            this.mouseButtonsReleased = UInt8[]
            this.elementsBeingClickedDownOn = Union{JulGame.IUIElement, JulGame.IEntity}[]
            this.mousePosition = JulGame.Math._Vector2{Int32}(0,0)
            this.mousePositionEditorGameWindowOffset = JulGame.Math._Vector2{Int32}(0,0)
            this.mousePositionWorld = JulGame.Math._Vector2{Float64}(0,0)
            this.quit = false
            this.scanCodes = Tuple{SDL2.SDL_Scancode, SubString{String}}[]
            this.scanCodeStrings = String[]
            this.joystick = Ptr{SDL2.SDL_Joystick}(C_NULL)
            for m in instances(SDL2.SDL_Scancode)
                codeString = "$(m)"
                code::SDL2.SDL_Scancode = m
                if codeString == "SDL_NUM_SCANCODES"
                    continue
                end
                push!(this.scanCodes, (code, SubString(codeString, 14, length(codeString))))
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
                this.numAxes = Int(SDL2.SDL_JoystickNumAxes(this.joystick))
                this.numButtons = Int(SDL2.SDL_JoystickNumButtons(this.joystick))
                this.numHats = Int(SDL2.SDL_JoystickNumHats(this.joystick))

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

    mutable struct _MouseUiHitLoop
        n_iter::Int
        n_skipped_inactive::Int
        n_skipped_canvas::Int
        n_skipped_ignore::Int
        n_miss_bounds::Int
        n_hit_inside::Int
        clickedAnElementAlready::Bool
        hoveredAnElementAlready::Bool
    end

    function _refresh_logical_mouse!(this::Input, evt::SDL2.SDL_Event)
        x = Int32[1]
        y = Int32[1]
        SDL2.SDL_GetMouseState(pointer(x), pointer(y))

        if evt.type == SDL2.SDL_MOUSEBUTTONDOWN || evt.type == SDL2.SDL_MOUSEBUTTONUP
            @debug "Mouse down: $(evt.type == SDL2.SDL_MOUSEBUTTONDOWN)"
            @debug "mouse state: $(x[1]), $(y[1])"
            window_focused = false
            if JulGame.MAIN !== nothing
                main = JulGame.current_main()
                window_focused = main.windowManager !== nothing && main.windowManager.isWindowFocused
            end
            @debug "window focused: $window_focused"
            if !window_focused
                @debug "using event coordinates"
                x[1] = Int32(evt.button.x)
                y[1] = Int32(evt.button.y)
                @debug "event coordinates: $(x[1]), $(y[1])"
            end
        end

        this.mousePosition = JulGame.Math._Vector2{Int32}(x[1], y[1])
        @debug "new mouse pos: $(this.mousePosition)"

        if !JulGame.IS_EDITOR
            main = JulGame.current_main()
            window_width = Ref{Cint}(0)
            window_height = Ref{Cint}(0)
            SDL2.SDL_GetWindowSize(main.windowManager.window, window_width, window_height)
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
            window_focused = (main.windowManager !== nothing && main.windowManager.isWindowFocused)
            this.mousePosition = JulGame.Math._Vector2{Int32}(
                clamp(floor(Int, scaled_x), 0, logical_size.x),
                clamp(floor(Int, scaled_y), 0, logical_size.y)
            )
            @debug "Scaled mouse position: window coords ($(x[1]), $(y[1])) -> logical coords ($(this.mousePosition.x), $(this.mousePosition.y)), window_focused: $window_focused"
        else
            main = JulGame.current_main()
            raw_mouse_x = x[1] - JulGame.EditorGameViewPosition.x
            raw_mouse_y = y[1] - JulGame.EditorGameViewPosition.y
            clamped_mouse_x = clamp(raw_mouse_x, 0, JulGame.EditorGameViewSize.x)
            clamped_mouse_y = clamp(raw_mouse_y, 0, JulGame.EditorGameViewSize.y)
            camera_size = main.scene.camera.size
            if JulGame.EditorGameViewSize.x > 0 && JulGame.EditorGameViewSize.y > 0
                scale_x = camera_size.x / JulGame.EditorGameViewSize.x
                scale_y = camera_size.y / JulGame.EditorGameViewSize.y
                scaled_x = clamped_mouse_x * scale_x
                scaled_y = clamped_mouse_y * scale_y
                this.mousePosition = JulGame.Math._Vector2{Int32}(floor(Int, scaled_x), floor(Int, scaled_y))
            else
                this.mousePosition = JulGame.Math._Vector2{Int32}(0, 0)
            end
        end
        return
    end

    @inline function _input_latency_profiler()::Union{Nothing, JulGame.Diagnostics.LatencyProfilerModule.LatencyProfiler}
        JulGame.MAIN === nothing && return nothing
        m = JulGame.current_main()
        (m.latencyProfiler !== nothing && m.latencyProfiler.enabled) || return nothing
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

    # Reverse then stable-sort by layer descending; avoids Base.sort for JuliaC --trim.
    # Sorting lives in `JulGame.UI.sort_reversed_ui_by_layer_for_input` (relationship dict access).

    @inline function _canvas_children(c::JulGame.ICanvas)::Vector{JulGame.IUIElement}
        cv = c::JulGame.UI.CanvasModule.Canvas
        return getfield(cv, :children)::Vector{JulGame.IUIElement}
    end

    function _ui_element_in_inactive_canvas(ui::JulGame.IUIElement, canvases::Vector{JulGame.ICanvas})::Bool
        for canvas in canvases
            cv = canvas::JulGame.UI.CanvasModule.Canvas
            getfield(cv, :isActive)::Bool && continue
            for c in _canvas_children(cv)
                c === ui && return true
            end
        end
        return false
    end

    function _entity_in_inactive_canvas(ent::JulGame.IEntity, canvases::Vector{JulGame.ICanvas})::Bool
        for canvas in canvases
            cv = canvas::JulGame.UI.CanvasModule.Canvas
            getfield(cv, :isActive)::Bool && continue
            for c in _canvas_children(cv)
                c === ent && return true
            end
        end
        return false
    end

    @Base.noinline function _input_trim_ui_set_hovered!(ui::JulGame.IUIElement, v::Bool)::Nothing
        Base.invokelatest(JulGame.UI.input_ui_set_isHovered!, ui, v)
        return nothing
    end

    @Base.noinline function _input_trim_ui_handle_event!(ui::JulGame.IUIElement, evt::SDL2.SDL_Event, x::Int32, y::Int32)::Nothing
        Base.invokelatest(JulGame.UI.handle_event, ui, evt, x, y)
        return nothing
    end

    @Base.noinline function _input_trim_entity_handle_event!(ent::JulGame.IEntity, evt::SDL2.SDL_Event, x::Int32, y::Int32)::Nothing
        Base.invokelatest(JulGame.UI.handle_event, ent, evt, x, y)
        return nothing
    end

    function _sort_reversed_entities_with_sprite_by_layer_desc(entities)
        tmp = empty(entities)
        for e in entities
            sp = getfield(e, :sprite)
            if sp !== nothing && sp !== C_NULL
                push!(tmp, e)
            end
        end
        n = length(tmp)
        n == 0 && return tmp
        out = similar(tmp, n)
        @inbounds for k in 1:n
            out[k] = tmp[n - k + 1]
        end
        @inbounds for i in 2:n
            cur = out[i]
            cl::Int = getfield(getfield(cur, :sprite), :layer)
            j = i
            while j > 1
                pl::Int = getfield(getfield(out[j - 1], :sprite), :layer)
                pl < cl || break
                out[j] = out[j - 1]
                j -= 1
            end
            out[j] = cur
        end
        return out
    end

    Base.@noinline function _poll_input_run_ui_entity_hit_loops!(
        this::Input,
        evt::SDL2.SDL_Event,
        prof_in::Union{Nothing, JulGame.Diagnostics.LatencyProfilerModule.LatencyProfiler},
        uiOrdered::Vector{JulGame.IUIElement},
        entsOrdered::AbstractVector{<:JulGame.IEntity},
        canvases::Vector{JulGame.ICanvas},
    )::Nothing
        hc = _MouseUiHitLoop(0, 0, 0, 0, 0, 0, false, false)
        @inbounds for i in eachindex(uiOrdered)
            _input_hit_scan_ui!(this, evt, prof_in, uiOrdered[i], canvases, hc)::Nothing
        end
        @inbounds for i in eachindex(entsOrdered)
            _input_hit_scan_entity!(this, evt, prof_in, entsOrdered[i], canvases, hc)::Nothing
        end
        return nothing
    end

    Base.@noinline function _input_hit_scan_ui!(this::Input, evt::SDL2.SDL_Event, prof::Union{Nothing, JulGame.Diagnostics.LatencyProfilerModule.LatencyProfiler}, @nospecialize(ui::JulGame.IUIElement), canvases::Vector{JulGame.ICanvas}, hc::_MouseUiHitLoop)::Nothing
        hc.n_iter += 1
        t_iter = time_ns()

        skipElement = !JulGame.UI.input_ui_is_active(ui)
        if skipElement
            hc.n_skipped_inactive += 1
        end
        if !skipElement && _ui_element_in_inactive_canvas(ui, canvases)
            skipElement = true
            hc.n_skipped_canvas += 1
        end

        if skipElement
            uname = JulGame.UI.input_ui_name(ui)
            uactive = JulGame.UI.input_ui_is_active(ui)
            @debug "Skipping element $uname - isActive: $uactive, ignoreInputEvents: N/A"
            _input_ui_hit_span!(prof, t_iter, :hit_ui_iter_skip_early)
            return nothing
        end

        _input_ui_hit_span!(prof, t_iter, :hit_ui_iter_probe_active_filter)
        t_prep0 = time_ns()

        eventWasInsideThisElement = true
        mouseX = this.mousePosition.x
        mouseY = this.mousePosition.y

        _input_ui_hit_span!(prof, t_prep0, :hit_ui_iter_probe_prep_hitbox)
        t_geom0 = time_ns()

        elementPosition = get_element_position(ui)
        _input_ui_hit_span!(prof, t_geom0, :hit_ui_iter_probe_get_position)
        t_sz0 = time_ns()

        elementSize = get_element_size(ui)
        _input_ui_hit_span!(prof, t_sz0, :hit_ui_iter_probe_get_size)
        t_unpk0 = time_ns()

        screenElementX = elementPosition.x
        screenElementY = elementPosition.y
        screenElementWidth = elementSize.x
        screenElementHeight = elementSize.y

        ename = JulGame.UI.input_ui_name(ui)
        @debug "Checking element '$(ename)': mouse($mouseX, $mouseY) vs element($screenElementX, $screenElementY, $screenElementWidth, $screenElementHeight)"

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
        _input_ui_hit_span!(prof, t_aabb, :hit_ui_iter_probe_aabb)

        if !eventWasInsideThisElement
            _input_trim_ui_set_hovered!(ui, false)
            t_ctr = time_ns()
            hc.n_miss_bounds += 1
            _input_ui_hit_span!(prof, t_ctr, :hit_ui_iter_miss_hover_counter_inc)
            return nothing
        end

        hc.n_hit_inside += 1
        t_hi = time_ns()
        @debug "  -> Mouse is INSIDE element '$(ename)'"

        clicked_down_here = clicked_down_on_this_element(this, ui)
        _input_ui_hit_span!(prof, t_hi, :hit_inside_1_clicked_down_query)
        t_hi = time_ns()

        fcc = JulGame.UI.input_ui_force_click_check(ui)
        canClickOnThisElement = (!hc.clickedAnElementAlready || fcc) && clicked_down_here
        @debug "  -> canClickOnThisElement: $canClickOnThisElement, clickedAnElementAlready: $(hc.clickedAnElementAlready), forceClickCheck: $fcc, clicked_down_on_this_element: $clicked_down_here"
        _input_ui_hit_span!(prof, t_hi, :hit_inside_2_can_click_bools)
        t_hi = time_ns()

        if !hc.clickedAnElementAlready || fcc
            shouldHandleEvent = (!hc.hoveredAnElementAlready && evt.type == SDL2.SDL_MOUSEMOTION) ||
                (fcc && evt.type == SDL2.SDL_MOUSEMOTION) ||
                (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && !hc.clickedAnElementAlready) ||
                (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && fcc) ||
                (canClickOnThisElement && evt.type == SDL2.SDL_MOUSEBUTTONUP)

            @debug "  -> shouldHandleEvent: $shouldHandleEvent (event type: $(evt.type), hoveredAnElementAlready: $(hc.hoveredAnElementAlready))"
            _input_ui_hit_span!(prof, t_hi, :hit_inside_3a_should_handle_expr)
            t_hi = time_ns()

            if shouldHandleEvent
                @debug "  -> Handling event for element '$(ename)'"
                _input_trim_ui_handle_event!(ui, evt, this.mousePosition.x, this.mousePosition.y)
                t_hi = time_ns()
                if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
                    push!(this.elementsBeingClickedDownOn, ui)
                    @debug "  -> Added '$(ename)' to elementsBeingClickedDownOn"
                end
                _input_ui_hit_span!(prof, t_hi, :hit_inside_5_push_clicked_down_optional)
                t_hi = time_ns()
            else
                _input_ui_hit_span!(prof, t_hi, :hit_inside_4_skip_should_handle_false)
                t_hi = time_ns()
            end
            if JulGame.UI.input_ui_is_hovered(ui)
                hc.hoveredAnElementAlready = true
            end
            _input_ui_hit_span!(prof, t_hi, :hit_inside_6_hover_an_element_already)
            t_hi = time_ns()
        else
            _input_ui_hit_span!(prof, t_hi, :hit_inside_3b_skip_clicked_guard)
            t_hi = time_ns()
        end

        if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
            @debug "Mouse button down at $(this.mousePosition) on element '$(ename)'"
        elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
            @debug "Mouse button up at $(this.mousePosition) on element '$(ename)'"
            if canClickOnThisElement
                @debug "CLICKED on '$(ename)' at $(this.mousePosition), skipping rest of event loop"
            else
                @debug "  -> Button up on '$(ename)' but canClickOnThisElement is false"
            end
            hc.clickedAnElementAlready = true
        end
        _input_ui_hit_span!(prof, t_hi, :hit_inside_7_mouse_btn_tail)
        return nothing
    end

    Base.@noinline function _input_hit_scan_entity!(this::Input, evt::SDL2.SDL_Event, prof::Union{Nothing, JulGame.Diagnostics.LatencyProfilerModule.LatencyProfiler}, ent::JulGame.IEntity, canvases::Vector{JulGame.ICanvas}, hc::_MouseUiHitLoop)::Nothing
        hc.n_iter += 1
        t_iter = time_ns()

        skipElement = !getfield(ent, :isActive)::Bool
        if skipElement
            hc.n_skipped_inactive += 1
        end
        if !skipElement && _entity_in_inactive_canvas(ent, canvases)
            skipElement = true
            hc.n_skipped_canvas += 1
        end
        if getfield(ent, :ignoreInputEvents)::Bool
            skipElement = true
            if getfield(ent, :isActive)::Bool
                hc.n_skipped_ignore += 1
            end
        end

        if skipElement
            ename = getfield(ent, :name)::String
            eactive = getfield(ent, :isActive)::Bool
            eign = getfield(ent, :ignoreInputEvents)::Bool
            @debug "Skipping element $ename - isActive: $eactive, ignoreInputEvents: $eign"
            _input_ui_hit_span!(prof, t_iter, :hit_ui_iter_skip_early)
            return nothing
        end

        _input_ui_hit_span!(prof, t_iter, :hit_ui_iter_probe_active_filter)
        t_prep0 = time_ns()

        eventWasInsideThisElement = true
        mouseX = this.mousePosition.x
        mouseY = this.mousePosition.y

        _input_ui_hit_span!(prof, t_prep0, :hit_ui_iter_probe_prep_hitbox)
        t_geom0 = time_ns()

        elementPosition = get_element_position(ent)
        _input_ui_hit_span!(prof, t_geom0, :hit_ui_iter_probe_get_position)
        t_sz0 = time_ns()

        elementSize = get_element_size(ent)
        _input_ui_hit_span!(prof, t_sz0, :hit_ui_iter_probe_get_size)
        t_unpk0 = time_ns()

        screenElementX = elementPosition.x
        screenElementY = elementPosition.y
        screenElementWidth = elementSize.x
        screenElementHeight = elementSize.y

        ename = getfield(ent, :name)::String
        @debug "Checking element '$(ename)': mouse($mouseX, $mouseY) vs element($screenElementX, $screenElementY, $screenElementWidth, $screenElementHeight)"

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
        _input_ui_hit_span!(prof, t_aabb, :hit_ui_iter_probe_aabb)

        if !eventWasInsideThisElement
            setfield!(ent, :isHovered, false)
            t_ctr = time_ns()
            hc.n_miss_bounds += 1
            _input_ui_hit_span!(prof, t_ctr, :hit_ui_iter_miss_hover_counter_inc)
            return nothing
        end

        hc.n_hit_inside += 1
        t_hi = time_ns()
        @debug "  -> Mouse is INSIDE element '$(ename)'"

        clicked_down_here = clicked_down_on_this_element(this, ent)
        _input_ui_hit_span!(prof, t_hi, :hit_inside_1_clicked_down_query)
        t_hi = time_ns()

        fcc = getfield(ent, :forceClickCheck)::Bool
        canClickOnThisElement = (!hc.clickedAnElementAlready || fcc) && clicked_down_here
        @debug "  -> canClickOnThisElement: $canClickOnThisElement, clickedAnElementAlready: $(hc.clickedAnElementAlready), forceClickCheck: $fcc, clicked_down_on_this_element: $clicked_down_here"
        _input_ui_hit_span!(prof, t_hi, :hit_inside_2_can_click_bools)
        t_hi = time_ns()

        if !hc.clickedAnElementAlready || fcc
            shouldHandleEvent = (!hc.hoveredAnElementAlready && evt.type == SDL2.SDL_MOUSEMOTION) ||
                (fcc && evt.type == SDL2.SDL_MOUSEMOTION) ||
                (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && !hc.clickedAnElementAlready) ||
                (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && fcc) ||
                (canClickOnThisElement && evt.type == SDL2.SDL_MOUSEBUTTONUP)

            @debug "  -> shouldHandleEvent: $shouldHandleEvent (event type: $(evt.type), hoveredAnElementAlready: $(hc.hoveredAnElementAlready))"
            _input_ui_hit_span!(prof, t_hi, :hit_inside_3a_should_handle_expr)
            t_hi = time_ns()

            if shouldHandleEvent
                @debug "  -> Handling event for element '$(ename)'"
                _input_trim_entity_handle_event!(ent, evt, this.mousePosition.x, this.mousePosition.y)
                t_hi = time_ns()
                if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
                    push!(this.elementsBeingClickedDownOn, ent)
                    @debug "  -> Added '$(ename)' to elementsBeingClickedDownOn"
                end
                _input_ui_hit_span!(prof, t_hi, :hit_inside_5_push_clicked_down_optional)
                t_hi = time_ns()
            else
                _input_ui_hit_span!(prof, t_hi, :hit_inside_4_skip_should_handle_false)
                t_hi = time_ns()
            end
            if getfield(ent, :isHovered)::Bool
                hc.hoveredAnElementAlready = true
            end
            _input_ui_hit_span!(prof, t_hi, :hit_inside_6_hover_an_element_already)
            t_hi = time_ns()
        else
            _input_ui_hit_span!(prof, t_hi, :hit_inside_3b_skip_clicked_guard)
            t_hi = time_ns()
        end

        if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
            @debug "Mouse button down at $(this.mousePosition) on element '$(ename)'"
        elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
            @debug "Mouse button up at $(this.mousePosition) on element '$(ename)'"
            if canClickOnThisElement
                @debug "CLICKED on '$(ename)' at $(this.mousePosition), skipping rest of event loop"
            else
                @debug "  -> Button up on '$(ename)' but canClickOnThisElement is false"
            end
            hc.clickedAnElementAlready = true
        end
        _input_ui_hit_span!(prof, t_hi, :hit_inside_7_mouse_btn_tail)
        return nothing
    end

    function poll_input(this::Input)
        prof = _input_latency_profiler()::Union{Nothing, JulGame.Diagnostics.LatencyProfilerModule.LatencyProfiler}
        t0 = Ref(time_ns())

        this.buttonsPressedDown = String[]
        this.mouseButtonsPressedDown = UInt8[]
        this.mouseButtonsReleased = UInt8[]  # Clear the released buttons each frame
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
                JulGame.dispatch_editor_sdl_event(this.editorCallback, evt)
            end

            if evt.type == SDL2.SDL_DROPFILE
                @debug "Dropped file: $(unsafe_string(evt.drop.file))"
                if JulGame.IS_EDITOR
                    push!(JulGame.EDITOR_SDL_DROP_FILE_PATHS, unsafe_string(evt.drop.file))
                end
                # TODO: Handle dropped file
                SDL2.SDL_free(evt.drop.file)
            elseif evt.type == SDL2.SDL_DROPTEXT
                @debug "Dropped text: $(unsafe_string(evt.drop.file))"
                if JulGame.IS_EDITOR
                    push!(JulGame.EDITOR_SDL_DROP_TEXT_PATHS, unsafe_string(evt.drop.file))
                end
                SDL2.SDL_free(evt.drop.file)
            elseif evt.type == SDL2.SDL_DROPBEGIN
                @debug "Drop begin"
            elseif evt.type == SDL2.SDL_DROPCOMPLETE
                @debug "Drop complete"
            elseif evt.type == SDL2.SDL_CLIPBOARDUPDATE
                @debug "Clipboard update"
            end

            #= Clipboard paste (Ctrl+V): disabled for JuliaC `--trim` static analysis (pulls in fragile
            # Base process / SDL paths from reachability). Re-enable when building without `--trim` or
            # when JuliaC supports this subgraph.
            if JulGame.IS_EDITOR && evt.type == SDL2.SDL_KEYDOWN
                if evt.key.keysym.sym == SDL2.LibSDL2.SDLK_v && (evt.key.keysym.mod & SDL2.LibSDL2.KMOD_CTRL) != 0
                    @debug "Ctrl+V detected, checking clipboard for image"
                    handle_clipboard_paste()
                end
            end
            =#

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

                main = JulGame.current_main()
                ui_hit_active = main.scene.uiElements !== nothing && !(JulGame.IS_EDITOR && !main.isGameModeRunningInEditor)
                if ui_hit_active
                    _input_ui_hit_span!(prof, t_ms_blk, :hit_mouse_evt_preamble)
                    t_ui_wall = time_ns()
                    t_hit = Ref(time_ns())
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_enter; evt = evt.type, mouse = (this.mousePosition.x, this.mousePosition.y), n_ui = length(main.scene.uiElements))
                    if main.scene.camera === nothing
                        _input_ui_hit_step!(prof, t_hit, :hit_ui_abort_camera)
                        @warn ("Camera is not set in the main scene.")
                        _input_poll_accumulate!(prof, t0, :mouse_ui_aborted_no_camera)
                        continue
                    end
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_camera_ok)

                    canvases = JulGame.ICanvas[]
                    for x in main.scene.uiElements
                        if isa(x, JulGame.ICanvas)
                            push!(canvases, x::JulGame.ICanvas)
                        end
                    end
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_filter_canvas; n_canvases = length(canvases))

                    # Use cached layer order instead of sorting every mouse event
                    # This avoids expensive allocations (reverse, sort, filter, vcat) on every input event
                    #elementsOrderedByLayerDescending = JulGame.MainLoopModule.get_input_layer_order(main)
                                        # uiElementsOrderedByLayerDescending = sort(reverse(allUIElements), by = uiElement -> uiElement.layer, rev = true)

                    uiElementsOrderedByLayerDescending = JulGame.UI.sort_reversed_ui_by_layer_for_input(main.scene.uiElements)
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_sort_ui; n = length(uiElementsOrderedByLayerDescending))

                    entitiesWithSpritesOrderedByLayerDescending = _sort_reversed_entities_with_sprite_by_layer_desc(main.scene.entities)
                    _input_ui_hit_step!(prof, t_hit, :hit_ui_sort_entities; n = length(entitiesWithSpritesOrderedByLayerDescending), n_entities = length(main.scene.entities))

                    # TODO: add rest of entities without sprites in default order
                    # restOfEntities = filter(entity -> entity.sprite === nothing || entity.sprite === C_NULL, main.scene.entities)
                    # append!(elementsOrderedByLayerDescending, restOfEntities)
                    n_ui_el = length(uiElementsOrderedByLayerDescending)
                    n_ent_el = length(entitiesWithSpritesOrderedByLayerDescending)
                    @debug "Checking $(n_ui_el + n_ent_el) elements for mouse event at $(this.mousePosition)"
                    prof_in = prof::Union{Nothing, JulGame.Diagnostics.LatencyProfilerModule.LatencyProfiler}
                    _poll_input_run_ui_entity_hit_loops!(
                        this,
                        evt,
                        prof_in,
                        uiElementsOrderedByLayerDescending,
                        entitiesWithSpritesOrderedByLayerDescending,
                        canvases,
                    )::Nothing
                    t_tail = Ref(time_ns())
                    if evt.type == SDL2.SDL_MOUSEBUTTONUP
                        this.elementsBeingClickedDownOn = Union{JulGame.IUIElement, JulGame.IEntity}[]
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
                    axis = SDL2.SDL_JoystickGetAxis(this.joystick, Cint(i))
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
                    button = SDL2.SDL_JoystickGetButton(this.joystick, Cint(i))

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

                    hat = SDL2.SDL_JoystickGetHat(this.joystick, Cint(i))
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

    function get_element_position(element::JulGame.IUIElement)::Math._Vector2{Int32}
        return JulGame.UI.input_ui_position(element)
    end

    function get_element_position(element::JulGame.IEntity)::Math._Vector2{Int32}
        sp = getfield(element, :sprite)
        if sp === nothing || sp === C_NULL
            return Math._Vector2{Int32}(0, 0)
        end
        lrp = getfield(sp, :lastRenderedScreenPosition)
        lrs = getfield(sp, :lastRenderedScreenSize)
        basePosition = lrp === nothing ? Math._Vector2{Int32}(0, 0) : lrp::Math._Vector2{Int32}
        baseSize = lrs === nothing ? Math._Vector2{Int32}(0, 0) : lrs::Math._Vector2{Int32}
        interactionScale = try
            getfield(sp, :interactionScale)
        catch
            1.0
        end
        if interactionScale < 1.0
            sizeDiff = Math._Vector2{Int32}(baseSize.x * (1.0 - interactionScale), baseSize.y * (1.0 - interactionScale))
            return Math._Vector2{Int32}(basePosition.x + sizeDiff.x / 2, basePosition.y + sizeDiff.y / 2)
        end
        return basePosition
    end

    function get_element_size(element::JulGame.IUIElement)::Math._Vector2{Int32}
        return JulGame.UI.input_ui_size(element)
    end

    function get_element_size(element::JulGame.IEntity)::Math._Vector2{Int32}
        sp = getfield(element, :sprite)
        if sp === nothing || sp === C_NULL
            return Math._Vector2{Int32}(0, 0)
        end
        lrs = getfield(sp, :lastRenderedScreenSize)
        baseSize = lrs === nothing ? Math._Vector2{Int32}(0, 0) : lrs::Math._Vector2{Int32}
        interactionScale = try
            getfield(sp, :interactionScale)
        catch
            1.0
        end
        return Math._Vector2{Int32}(baseSize.x * interactionScale, baseSize.y * interactionScale)
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

        # If we have access to the WindowManager through the main loop, delegate window events to it
        if JulGame.MAIN !== nothing
            main = JulGame.current_main()
            if main.windowManager !== nothing
                JulGame.WindowManagerModule.handle_window_event(event.window)
            end
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

    function _delete_first!(v::Vector{UInt8}, x::UInt8)
        for i in eachindex(v)
            if @inbounds(v[i]) == x
                deleteat!(v, i)
                return
            end
        end
        return
    end

    function handle_mouse_event(this::Input, event::SDL2.SDL_Event)
        if event.button.button == SDL2.SDL_BUTTON_LEFT || event.button.button == SDL2.SDL_BUTTON_MIDDLE || event.button.button == SDL2.SDL_BUTTON_RIGHT
            button = event.button.button % UInt8
            if event.type == SDL2.SDL_MOUSEBUTTONDOWN && !(button in this.mouseButtonsHeldDown)
                push!(this.mouseButtonsPressedDown, button)
                push!(this.mouseButtonsHeldDown, button)
            elseif event.type == SDL2.SDL_MOUSEBUTTONUP && (button in this.mouseButtonsHeldDown)
                push!(this.mouseButtonsReleased, button)
                _delete_first!(this.mouseButtonsHeldDown, button)
            end
        end
    end

    """
        handle_clipboard_paste()

    Handle Ctrl+V clipboard paste for images in the editor.
    Checks if clipboard contains image data and creates a temporary file for import.
    """
    function handle_clipboard_paste()::Nothing
        # Disabled for JuliaC `--trim`; full implementation kept below for easy restore.
        return nothing
        #= 
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
        =#
    end

    """
        handle_x11_clipboard_image()

    Try to get image data from X11 clipboard using xclip command.
    """
    function handle_x11_clipboard_image()
        # Image paste via xclip uses `Base.Cmd` (`success`/`read`/`open`), which drags in Base's
        # process and I/O show stack. JuliaC `--trim` cannot verify that code; SDL text clipboard in
        # `handle_clipboard_paste` is unchanged.
        return nothing
    end

    """
        handle_macos_clipboard_image()

    Try to get image data from macOS clipboard using pbpaste command.
    """
    function handle_macos_clipboard_image()
        # Image paste via pbpaste uses `Base.Cmd`; see `handle_x11_clipboard_image`.
        return nothing
    end

    """
        handle_windows_clipboard_image()

    Try to get image data from Windows clipboard using PowerShell.
    """
    function handle_windows_clipboard_image()
        # Image paste via PowerShell uses `Base.Cmd`; see `handle_x11_clipboard_image`.
        return nothing
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
        push!(JulGame.EDITOR_SDL_DROP_FILE_PATHS, filepath)
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
        return get_button_held_down(JulGame.current_main().input, button)
    end

    function get_button_pressed(button::String)
        return get_button_pressed(JulGame.current_main().input, button)
    end

    function get_button_pressed(this::Input, button::String)
        if uppercase(button) in this.buttonsPressedDown
            return true
        end
        return false
    end

    function get_button_released(button::String)
        return get_button_released(JulGame.current_main().input, button)
    end

    function get_button_released(this::Input, button::String)
        if uppercase(button) in this.buttonsReleased
            return true
        end
        return false
    end

    function get_mouse_button(this::Input, button)
        b = button isa UInt8 ? button : UInt8(button)
        return b in this.mouseButtonsHeldDown
    end

    function get_mouse_button(button)
        return get_mouse_button(JulGame.current_main().input, button)
    end

    function get_mouse_button_pressed(this::Input, button)
        b = button isa UInt8 ? button : UInt8(button)
        return b in this.mouseButtonsPressedDown
    end

    function get_mouse_button_pressed(button)
        return get_mouse_button_pressed(JulGame.current_main().input, button)
    end

    function get_mouse_button_released(this::Input, button)
        b = button isa UInt8 ? button : UInt8(button)
        return b in this.mouseButtonsReleased
    end

    function get_mouse_button_released(button)
        return get_mouse_button_released(JulGame.current_main().input, button)
    end

    function get_mouse_position(this::Input)
        return this.mousePosition
    end

    function get_mouse_position()
        return get_mouse_position(JulGame.current_main().input)
    end

    function get_mouse_position_in_world_space(this::Input)
        return this.mousePositionWorld
    end

    function get_mouse_position_in_world_space()
        return get_mouse_position_in_world_space(JulGame.current_main().input)
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

    function init_sdl_event()::Ptr{SDL2.SDL_Event}
        ptr_event = Ptr{SDL2.SDL_Event}(Libc.calloc(1, sizeof(SDL2.SDL_Event)))
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
        x = JulGame.Math.TypeConversions.safe_int32_convert(window_x)
        y = JulGame.Math.TypeConversions.safe_int32_convert(window_y)
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
        main = JulGame.current_main()
        simulate_mouse_click(main.input, main.windowManager.window, x, y)
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
        lift_mouse_after_simulated_click(JulGame.current_main().input)
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
        simulate_key_press(JulGame.current_main().input, key)
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
        set_cursor_with_image(JulGame.current_main().input, imagePath, x, y, scale_factor)
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
