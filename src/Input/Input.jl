#todo: separate mouse, keyboard, gamepad, and window into their own files
module InputModule
    using ..JulGame
    using ..JulGame.Math
    
    export Input
    mutable struct Input
        buttonsPressedDown::Vector{String}
        buttonsHeldDown::Vector{String}
        buttonsReleased::Vector{String}
        debug::Bool
        isWindowFocused::Bool
        main
        mouseButtonsPressedDown::Vector
        mouseButtonsHeldDown::Vector
        mouseButtonsReleased::Vector
        mousePosition
        joystick
        scanCodeStrings::Vector{String}
        scanCodes::Vector
        scene
        quit::Bool
        
        #Gamepad
        jaxis
        xDir
        yDir
        numAxes
        numButtons
        numHats
        button

        function Input()
            this = new()

            this.buttonsPressedDown = []
            this.buttonsHeldDown = []
            this.buttonsReleased = []
            this.debug = false
            this.isWindowFocused = true
            this.mouseButtonsPressedDown = []
            this.mouseButtonsHeldDown = []
            this.mouseButtonsReleased = []
            this.mousePosition = Math.Vector2(0,0)
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
                println("Warning: No joysticks connected!")
                this.numAxes = 0
                this.numButtons = 0
                this.numHats = 0
            else
                # Load joystick
                this.joystick = SDL2.SDL_JoystickOpen(0)
                if this.joystick == C_NULL
                    println("Warning: Unable to open game controller! SDL Error: ", unsafe_string(SDL2.SDL_GetError()))
                end
                name = SDL2.SDL_JoystickName(this.joystick)
                this.numAxes = SDL2.SDL_JoystickNumAxes(this.joystick)
                this.numButtons = SDL2.SDL_JoystickNumButtons(this.joystick)
                this.numHats = SDL2.SDL_JoystickNumHats(this.joystick)

                println("Now reading from joystick '$(unsafe_string(name))' with:")
                println("$(this.numAxes) axes")
                println("$(this.numButtons) buttons")
                println("$(this.numHats) hats")

            end
            this.jaxis = C_NULL
            this.xDir = 0
            this.yDir = 0
            this.button = 0

            return this
        end
    end

    function Base.getproperty(this::Input, s::Symbol)
        if s == :pollInput
            function()
                this.buttonsPressedDown = []
                didMouseEventOccur = false
                event_ref = Ref{SDL2.SDL_Event}()
                while Bool(SDL2.SDL_PollEvent(event_ref))
                    evt = event_ref[]
                    this.handleWindowEvents(evt)
                    if evt.type == SDL2.SDL_MOUSEMOTION || evt.type == SDL2.SDL_MOUSEBUTTONDOWN || evt.type == SDL2.SDL_MOUSEBUTTONUP
                        didMouseEventOccur = true
                        if this.scene.screenButtons != C_NULL
                            x,y = Int[1], Int[1]
                            SDL2.SDL_GetMouseState(pointer(x), pointer(y))
                            
                            this.mousePosition = Math.Vector2(x[1], y[1])
                            for screenButton in this.scene.screenButtons
                                # Check position of button to see which we are interacting with
                                eventWasInsideThisButton = true
                                if x[1] < screenButton.position.x + MAIN.scene.camera.startingCoordinates.x
                                    eventWasInsideThisButton = false
                                elseif x[1] > MAIN.scene.camera.startingCoordinates.x + screenButton.position.x + screenButton.dimensions.x * MAIN.zoom
                                    eventWasInsideThisButton = false
                                elseif y[1] < screenButton.position.y + MAIN.scene.camera.startingCoordinates.y
                                    eventWasInsideThisButton = false
                                elseif y[1] > MAIN.scene.camera.startingCoordinates.y + screenButton.position.y + screenButton.dimensions.y * MAIN.zoom
                                    eventWasInsideThisButton = false
                                end

                                screenButton.mouseOverSprite = eventWasInsideThisButton
                                if !eventWasInsideThisButton
                                    continue
                                end
                                
                                screenButton.handleEvent(evt, x, y)
                            end
                        end

                        this.handleMouseEvent(evt)
                    end 

                    #if evt.type == SDL2.SDL_JOYAXISMOTION
                        if evt.jaxis.which == 0
                            this.jaxis = evt.jaxis
                        end
                        for i in 0:this.numAxes-1
                            axis = SDL2.SDL_JoystickGetAxis(this.joystick, i)
                            if i < 0
                                println("Axis $i: $(SDL2.SDL_JoystickGetAxis(this.joystick, i))")
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
                        # println("x:$(this.xDir), y:$(this.yDir)")
                        for i in 0:this.numButtons-1
                            button = SDL2.SDL_JoystickGetButton(this.joystick, i)

                            if button != 0
                                println("Button $i: $(button)")
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
                                println("Hat $i: $(hat)")
                            end
                        end
                        
                    #end

                    if evt.type == SDL2.SDL_QUIT
                        this.quit = true
                        return -1
                    end
                    if evt.type == SDL2.SDL_KEYDOWN && evt.key.keysym.scancode == SDL2.SDL_SCANCODE_F3
                        this.debug = !this.debug
                    end
                end
                if !didMouseEventOccur
                    this.mouseButtonsPressedDown = []
                    this.mouseButtonsReleased = []
                end
                keyboardState = unsafe_wrap(Array, SDL2.SDL_GetKeyboardState(C_NULL), 290; own = false)
                this.handleKeyEvent(keyboardState)
            end
        elseif s == :checkScanCode
            function (keyboardState, keyState, scanCodes)
                for scanCode in scanCodes
                    if keyboardState[Int(scanCode) + 1] == keyState
                        return true
                    end
                end
                return false
            end    
        elseif s == :handleWindowEvents
            function (event)
                if event.type != SDL2.SDL_WINDOWEVENT
                    return
                end
                windowEvent = event.window.event
                
                # Uncomment to debug window events
                if windowEvent == SDL2.SDL_WINDOWEVENT_SHOWN
                    #println(string("Window $(event.window.windowID) shown", ))
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_HIDDEN
                    #println(string("Window $(event.window.windowID) hidden"))
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_EXPOSED
                    #println(string("Window $(event.window.windowID) exposed"))
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_MOVED
                    #println(string("Window $(event.window.windowID) moved to $(event.window.data1),$(event.window.data2)"))
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_RESIZED # todo: update zoom and viewport size here
                    #println(string("Window $(event.window.windowID) resized to $(event.window.data1)x$(event.window.data2)"))
                    this.main.updateViewport(event.window.data1, event.window.data2)
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_SIZE_CHANGED
                    #println(string("Window $(event.window.windowID) size changed to $(event.window.data1)x$(event.window.data2)"))
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_MINIMIZED
                    #println(string("Window $(event.window.windowID) minimized"))
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_MAXIMIZED
                    #println(string("Window $(event.window.windowID) maximized"))
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_RESTORED
                    #println(string("Window $(event.window.windowID) restored"))
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_ENTER
                    #println(string("Mouse entered window $(event.window.windowID)"))
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_LEAVE
                    #println(string("Mouse left window $(event.window.windowID)"))
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_FOCUS_GAINED
                    #println(string("Window $(event.window.windowID) gained keyboard focus"))
                    this.isWindowFocused = true
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_FOCUS_LOST
                    #println(string("Window $(event.window.windowID) lost keyboard focus"))
                    this.isWindowFocused = false

                elseif windowEvent == SDL2.SDL_WINDOWEVENT_CLOSE
                    #println(string("Window $(event.window.windowID) closed"))
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_TAKE_FOCUS
                    #println(string("Window $(event.window.windowID) is offered a focus"))
                elseif windowEvent == SDL2.SDL_WINDOWEVENT_HIT_TEST
                    #println(string("Window $(event.window.windowID) has a special hit test"))
                else
                    #println(string("Window $(event.window.windowID) got unknown event $(event.window.event)"))   
                end    
            end
        elseif s == :handleKeyEvent
            function(keyboardState)
                buttonsPressedDown = this.buttonsPressedDown

                count = 1
                for scanCode in this.scanCodes
                    button = scanCode[2]
                    if this.checkScanCode(keyboardState, 1, [scanCode[1]]) && !(button in this.buttonsHeldDown)
                        push!(buttonsPressedDown, button)
                        push!(this.buttonsHeldDown, button)
                    elseif this.checkScanCode(keyboardState, 0, [scanCode[1]])
                        if button in this.buttonsHeldDown
                            deleteat!(this.buttonsHeldDown, findfirst(x -> x == button, this.buttonsHeldDown))
                        end
                    end
                end
                
                this.buttonsPressedDown = buttonsPressedDown
            end
        elseif s == :handleMouseEvent
            function(event)
                mouseButtons = []
                mouseButtonsUp = []
                mouseButton = C_NULL
                mouseButtonUp = C_NULL

                if event.button.button == SDL2.SDL_BUTTON_LEFT || event.button.button == SDL2.SDL_BUTTON_MIDDLE || event.button.button == SDL2.SDL_BUTTON_RIGHT
                    if !(mouseButton in mouseButtons)
                        if event.type == SDL2.SDL_MOUSEBUTTONDOWN
                            mouseButton = event.button.button
                            push!(mouseButtons, mouseButton)
                        elseif event.type == SDL2.SDL_MOUSEBUTTONUP
                            mouseButtonUp = event.button.button
                            push!(mouseButtonsUp, mouseButtonUp)
                        end
                    end
                end

                this.mouseButtonsPressedDown = mouseButtons
                for mouseButton in mouseButtons
                    if !(mouseButton in this.mouseButtonsHeldDown)
                        push!(this.mouseButtonsHeldDown, mouseButton)
                    end
                end
                for mouseButton in mouseButtonsUp
                    if mouseButton in this.mouseButtonsHeldDown
                        deleteat!(this.mouseButtonsHeldDown, findfirst(x -> x == mouseButton, this.mouseButtonsHeldDown))
                    end
                end
                this.mouseButtonsReleased = mouseButtonsUp
            end
        elseif s == :getButtonHeldDown
            function(button)
                if button in this.buttonsHeldDown
                    return true
                end
                return false
            end
        elseif s == :getButtonPressed
            function(button)
                if button in this.buttonsPressedDown
                    return true
                end
                return false
            end
        elseif s == :getButtonReleased
            function(button)
                if button in this.buttonsReleased
                    return true
                end
                return false
            end
        elseif s == :getMouseButton
            function(button)
                if button in this.mouseButtonsHeldDown
                    return true
                end
                return false
            end
        elseif s == :getMouseButtonPressed
            function(button)
                if button in this.mouseButtonsPressedDown
                    return true
                end
                return false
            end
        elseif s == :getMouseButtonReleased
            function(button)
                if button in this.mouseButtonsReleased
                    return true
                end
                return false
            end
        else
            try
                getfield(this, s)
            catch e
                println(e)
            end
        end
    end
end