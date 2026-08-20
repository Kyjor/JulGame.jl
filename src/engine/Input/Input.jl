#todo: separate mouse, keyboard, gamepad, and window into their own files
module InputModule
    using ..JulGame
    using ..JulGame.Math
    using ..JGStaticModule
    using ..UIHitTestModule
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
        uiHitTestBuffer::HitTestBuffer

        #Gamepad
        jaxis
        xDir
        yDir
        numAxes
        numButtons
        numHats
        button
        prevGamepadButton::Bool
        prevXDir::Int
        prevYDir::Int

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
            this.uiHitTestBuffer = HitTestBuffer()
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
            this.joystick = C_NULL
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
            this.prevGamepadButton = false
            this.prevXDir = 0
            this.prevYDir = 0

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

            if evt.type == SDL2.SDL_MOUSEMOTION || evt.type == SDL2.SDL_MOUSEBUTTONDOWN || evt.type == SDL2.SDL_MOUSEBUTTONUP
                this.didMouseEventOccur = true
                if evt.type == SDL2.SDL_MOUSEMOTION
                    this.didMouseMotionOccur = true
                end
                if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
                    @debug("Mouse button down at $(this.mousePosition)")
                end

                ui_hit_active = JulGame.MAIN.scene.uiElements !== nothing && !(JulGame.IS_EDITOR && !JulGame.MAIN.isGameModeRunningInEditor)
                if ui_hit_active
                    if JulGame.MAIN.scene.camera === nothing
                        @warn ("Camera is not set in the main scene.")
                        continue
                    end

                    # Pared + sorted into reused buffers; see _build_hit_test_candidates!
                    elementsOrderedByLayerDescending, nUICandidates = _build_hit_test_candidates!()

                    clickedAnElementAlready = false
                    hoveredAnElementAlready = false
                    mouseX = this.mousePosition.x
                    mouseY = this.mousePosition.y
                    buf = this.uiHitTestBuffer
                    clear!(buf)
                    for element in elementsOrderedByLayerDescending
                        skipElement = !element.isActive
                        # Re-check here (despite build-time paring) because a click
                        # handler earlier in this loop can deactivate a canvas
                        if !skipElement && element in _inactiveCanvasChildren
                            skipElement = true
                        end
                        if isa(element, JulGame.IEntity) && element.ignoreInputEvents
                            skipElement = true
                        end
                        if skipElement
                            @debug "Skipping element $(element.name) - isActive: $(element.isActive)"
                            continue
                        end

                        elementPosition = get_element_position(element)
                        elementSize = get_element_size(element)
                        push_rect!(
                            buf, element,
                            elementPosition.x, elementPosition.y,
                            elementPosition.x + elementSize.x, elementPosition.y + elementSize.y,
                        )
                    end
                    hit_idx = lib_available() ?
                        run_static_hit_test_batch!(buf, mouseX, mouseY) :
                        first_hit_index_julia(buf, mouseX, mouseY)

                    for i in 1:buf.count
                        element = buf.elements[i]
                        if i != hit_idx
                            element.isHovered = false
                            continue
                        end

                        @debug "  -> Mouse is INSIDE element '$(element.name)'"
                        clicked_down_here = clicked_down_on_this_element(this, element)
                        canClickOnThisElement = (!clickedAnElementAlready || element.forceClickCheck) && clicked_down_here

                        if !clickedAnElementAlready || element.forceClickCheck
                            shouldHandleEvent = (!hoveredAnElementAlready && evt.type == SDL2.SDL_MOUSEMOTION) ||
                                (element.forceClickCheck && evt.type == SDL2.SDL_MOUSEMOTION) ||
                                (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && !clickedAnElementAlready) ||
                                (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && element.forceClickCheck) ||
                                (canClickOnThisElement && evt.type == SDL2.SDL_MOUSEBUTTONUP)

                            if shouldHandleEvent
                                JulGame.UI.handle_event(element, evt, mouseX, mouseY)
                                if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
                                    push!(this.elementsBeingClickedDownOn, element)
                                end
                            end
                            if element.isHovered
                                hoveredAnElementAlready = true
                            end
                        end

                        if evt.type == SDL2.SDL_MOUSEBUTTONUP
                            clickedAnElementAlready = true
                        end
                    end
                    if evt.type == SDL2.SDL_MOUSEBUTTONUP
                        this.elementsBeingClickedDownOn = []
                    end
                end

                handle_mouse_event(this, evt)
            end

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

        end

        update_joystick_state!(this)

        # if this.isTestButtonClicked
        #     lift_mouse_after_simulated_click(this)
        # end
    end

    const JOYSTICK_DEAD_ZONE = Int16(8000)

    """
    Sample stick / D-pad / face button once per frame (not only on joystick SDL events)
    so axes don't stick. Direction edges push LEFT/RIGHT/UP/DOWN into buttonsPressedDown;
    South/A (button 0) rising edge pushes GAMEPAD_CONFIRM.
    """
    function update_joystick_state!(this::Input)
        this.xDir = 0
        this.yDir = 0
        this.button = 0
        this.joystick == C_NULL && return

        if this.numAxes > 0
            axisX = SDL2.SDL_JoystickGetAxis(this.joystick, 0)
            if axisX < -JOYSTICK_DEAD_ZONE
                this.xDir = -1
            elseif axisX > JOYSTICK_DEAD_ZONE
                this.xDir = 1
            end
        end
        if this.numAxes > 1
            axisY = SDL2.SDL_JoystickGetAxis(this.joystick, 1)
            if axisY < -JOYSTICK_DEAD_ZONE
                this.yDir = -1
            elseif axisY > JOYSTICK_DEAD_ZONE
                this.yDir = 1
            end
        end

        if this.numHats > 0
            hat = SDL2.SDL_JoystickGetHat(this.joystick, 0)
            (hat & SDL2.SDL_HAT_LEFT) != 0 && (this.xDir = -1)
            (hat & SDL2.SDL_HAT_RIGHT) != 0 && (this.xDir = 1)
            (hat & SDL2.SDL_HAT_UP) != 0 && (this.yDir = -1)
            (hat & SDL2.SDL_HAT_DOWN) != 0 && (this.yDir = 1)
        end

        # Rising-edge digital directions (match keyboard get_button_pressed feel)
        if this.xDir == -1 && this.prevXDir != -1
            push!(this.buttonsPressedDown, "LEFT")
        elseif this.xDir == 1 && this.prevXDir != 1
            push!(this.buttonsPressedDown, "RIGHT")
        end
        if this.yDir == -1 && this.prevYDir != -1
            push!(this.buttonsPressedDown, "UP")
        elseif this.yDir == 1 && this.prevYDir != 1
            push!(this.buttonsPressedDown, "DOWN")
        end
        this.prevXDir = this.xDir
        this.prevYDir = this.yDir

        buttonHeld = this.numButtons > 0 && SDL2.SDL_JoystickGetButton(this.joystick, 0) != 0
        this.button = buttonHeld ? 1 : 0
        if buttonHeld && !this.prevGamepadButton
            push!(this.buttonsPressedDown, "GAMEPAD_CONFIRM")
        end
        this.prevGamepadButton = buttonHeld
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