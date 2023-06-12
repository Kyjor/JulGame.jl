include("Button.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Input
    buttonsPressedDown::Array{String}
    buttonsHeldDown::Array{String}
    buttonsReleased::Array{String}
    debug::Bool
    mouseButtonsPressedDown::Array
    mouseButtonsHeldDown::Array
    mouseButtonsReleased::Array
    mousePosition
    scanCodes::Array{String}
    scene
    quit::Bool

    function Input()
        this = new()

        this.buttonsPressedDown = []
        this.buttonsHeldDown = []
        this.buttonsReleased = []
        this.debug = false
        this.mouseButtonsPressedDown = []
        this.mouseButtonsHeldDown = []
        this.mouseButtonsReleased = []
        this.mousePosition = Math.Vector2(0,0)
        this.quit = false
        this.scanCodes = []
        for m in instances(SDL_Scancode)
            code = "$(m)"
            #println(SubString(code, 14, length(code)))
            push!(this.scanCodes, SubString(code, 14, length(code)))
        end

        return this
    end
end

function Base.getproperty(this::Input, s::Symbol)
    if s == :pollInput
        function()
            didMouseEventOccur = false
            event_ref = Ref{SDL_Event}()
            while Bool(SDL_PollEvent(event_ref))
                evt = event_ref[]
                this.handleWindowEvents(evt)
                if evt.type == SDL_MOUSEMOTION || evt.type == SDL_MOUSEBUTTONDOWN || evt.type == SDL_MOUSEBUTTONUP
                    didMouseEventOccur = true
                    if this.scene.screenButtons != C_NULL
                        x,y = Int[1], Int[1]
                        SDL_GetMouseState(pointer(x), pointer(y))
                        
                        this.mousePosition = Math.Vector2(x[1], y[1])
                        for screenButton in this.scene.screenButtons
                            # Check position of button to see which we are interacting with
                            eventWasInsideThisButton = true

                            if x[1] < screenButton.position.x
                                eventWasInsideThisButton = false
                            elseif x[1] > screenButton.position.x + screenButton.dimensions.x
                                eventWasInsideThisButton = false
                            elseif y[1] < screenButton.position.y
                                eventWasInsideThisButton = false
                            elseif y[1] > screenButton.position.y + screenButton.dimensions.y
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

                if evt.type == SDL_QUIT
                    this.quit = true
                    return -1
                end
                if evt.type == SDL_KEYDOWN && evt.key.keysym.scancode == SDL_SCANCODE_F3
                    this.debug = !this.debug
                end
            end
            if !didMouseEventOccur
                this.mouseButtonsPressedDown = []
                this.mouseButtonsReleased = []
            end
            keyboardState = unsafe_wrap(Array, SDL_GetKeyboardState(C_NULL), 290; own = false)
            this.handleKeyEvent(keyboardState)
        end
    elseif s == :checkScanCode
        function (keyboardState, keyState, scanCodes)
            for scanCode in scanCodes
                if keyboardState[Integer(scanCode) + 1] == keyState
                    return true
                end
            end
            return false
        end    
    elseif s == :handleWindowEvents
        function (event)
            if event.type != SDL_WINDOWEVENT
                return
            end
            windowEvent = event.window.event
            
            # if windowEvent == SDL_WINDOWEVENT_SHOWN
            #     println(string("Window $(event.window.windowID) shown", ))
            # elseif windowEvent == SDL_WINDOWEVENT_HIDDEN
            #     println(string("Window $(event.window.windowID) hidden"))
            # elseif windowEvent == SDL_WINDOWEVENT_EXPOSED
            #     println(string("Window $(event.window.windowID) exposed"))
            # elseif windowEvent == SDL_WINDOWEVENT_MOVED
            #     println(string("Window $(event.window.windowID) moved to $(event.window.data1),$(event.window.data2)"))
            # elseif windowEvent == SDL_WINDOWEVENT_RESIZED
            #     println(string("Window $(event.window.windowID) resized to $(event.window.data1)x$(event.window.data2)"))
            # elseif windowEvent == SDL_WINDOWEVENT_SIZE_CHANGED
            #     println(string("Window $(event.window.windowID) size changed to $(event.window.data1)x$(event.window.data2)"))
            # elseif windowEvent == SDL_WINDOWEVENT_MINIMIZED
            #     println(string("Window $(event.window.windowID) minimized"))
            # elseif windowEvent == SDL_WINDOWEVENT_MAXIMIZED
            #     println(string("Window $(event.window.windowID) maximized"))
            # elseif windowEvent == SDL_WINDOWEVENT_RESTORED
            #     println(string("Window $(event.window.windowID) restored"))
            # elseif windowEvent == SDL_WINDOWEVENT_ENTER
            #     println(string("Mouse entered window $(event.window.windowID)"))
            # elseif windowEvent == SDL_WINDOWEVENT_LEAVE
            #     println(string("Mouse left window $(event.window.windowID)"))
            # elseif windowEvent == SDL_WINDOWEVENT_FOCUS_GAINED
            #     println(string("Window $(event.window.windowID) gained keyboard focus"))
            # elseif windowEvent == SDL_WINDOWEVENT_FOCUS_LOST
            #     println(string("Window $(event.window.windowID) lost keyboard focus"))
            # elseif windowEvent == SDL_WINDOWEVENT_CLOSE
            #     println(string("Window $(event.window.windowID) closed"))
            # elseif windowEvent == SDL_WINDOWEVENT_TAKE_FOCUS
            #     println(string("Window $(event.window.windowID) is offered a focus"))
            # elseif windowEvent == SDL_WINDOWEVENT_HIT_TEST
            #     println(string("Window $(event.window.windowID) has a special hit test"))
            # else
            #     println(string("Window $(event.window.windowID) got unknown event $(event.window.event)"))   
            # end    
        end
    elseif s == :handleKeyEvent
        function(keyboardState)
            buttons = []
            button = "Button_None"

            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_W, SDL_SCANCODE_UP])
                button = "Button_Up"
                if !(button in buttons)
                    push!(buttons, button)
                end
            else
                button = "Button_Up"
                if button in this.buttonsHeldDown
                    deleteat!(this.buttonsHeldDown, findfirst(x -> x == button, this.buttonsHeldDown))
                end
            end
            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_A, SDL_SCANCODE_LEFT])
                button = "Button_Left"
                if !(button in buttons)
                    push!(buttons, button)
                end
            else
                button = "Button_Left"
                if button in this.buttonsHeldDown
                    deleteat!(this.buttonsHeldDown, findfirst(x -> x == button, this.buttonsHeldDown))
                end
            end
            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_S, SDL_SCANCODE_DOWN])
                button = "Button_Down"
                if !(button in buttons)
                    push!(buttons, button)
                end
            else
                button = "Button_Down"
                if button in this.buttonsHeldDown
                    deleteat!(this.buttonsHeldDown, findfirst(x -> x == button, this.buttonsHeldDown))
                end
            end
            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_D, SDL_SCANCODE_RIGHT])
                button = "Button_Right"
                if !(button in buttons)
                    push!(buttons, button)
                end
            else 
                button = "Button_Right"
                if button in this.buttonsHeldDown
                    deleteat!(this.buttonsHeldDown, findfirst(x -> x == button, this.buttonsHeldDown))
                end
            end
            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_SPACE])
                button = "Button_Jump"
                if !(button in buttons)
                    push!(buttons, button)
                end
            else
                button = "Button_Jump"
                if button in this.buttonsHeldDown
                    deleteat!(this.buttonsHeldDown, findfirst(x -> x == button, this.buttonsHeldDown))
                end
            end

            for button in buttons
                if !(button in this.buttonsHeldDown)
                    push!(this.buttonsHeldDown, button)
                end
            end
            this.buttonsPressedDown = buttons
        end
    elseif s == :handleMouseEvent
        function(event)
            mouseButtons = []
            mouseButtonsUp = []
            mouseButton = C_NULL
            mouseButtonUp = C_NULL

            if event.button.button == SDL_BUTTON_LEFT || event.button.button == SDL_BUTTON_MIDDLE || event.button.button == SDL_BUTTON_RIGHT
                if !(mouseButton in mouseButtons)
                    if event.type == SDL_MOUSEBUTTONDOWN
                        mouseButton = event.button.button
                        push!(mouseButtons, mouseButton)
                    elseif event.type == SDL_MOUSEBUTTONUP
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