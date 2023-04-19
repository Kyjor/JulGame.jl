include("Button.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Input
    buttons::Array{String}
    debug::Bool
    mouseButtons::Array
    mousePosition
    scene
    quit::Bool

    function Input()
        this = new()

        this.buttons = []
        this.debug = false
        this.mouseButtons = []
        this.mousePosition = Math.Vector2(0,0)
        this.quit = false

        return this
    end
end

function Base.getproperty(this::Input, s::Symbol)
    if s == :pollInput
        function()
            
            event_ref = Ref{SDL_Event}()
            while Bool(SDL_PollEvent(event_ref))
                evt = event_ref[]
                this.handleWindowEvents(evt)
                if evt.type == SDL_MOUSEMOTION || evt.type == SDL_MOUSEBUTTONDOWN || evt.type == SDL_MOUSEBUTTONUP
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
            end
            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_A, SDL_SCANCODE_LEFT])
                button = "Button_Left"
                if !(button in buttons)
                    push!(buttons, button)
                end
            end
            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_S, SDL_SCANCODE_DOWN])
                button = "Button_Down"
                if !(button in buttons)
                    push!(buttons, button)
                end
            end
            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_D, SDL_SCANCODE_RIGHT])
                button = "Button_Right"
                if !(button in buttons)
                    push!(buttons, button)
                end
            end
            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_SPACE])
                button = "Button_Jump"
                if !(button in buttons)
                    push!(buttons, button)
                end
            end

            this.buttons = buttons
        end
    elseif s == :handleMouseEvent
        function(event)
            mouseButtons = []
            mouseButton = C_NULL

            if event.button.button == SDL_BUTTON_LEFT
                mouseButton = SDL_BUTTON_LEFT
                if !(mouseButton in mouseButtons)
                    push!(mouseButtons, mouseButton)
                end
            end
            if event.button.button == SDL_BUTTON_MIDDLE
                mouseButton = SDL_BUTTON_MIDDLE
                if !(mouseButton in mouseButtons)
                    push!(mouseButtons, mouseButton)
                end
            end
            if event.button.button == SDL_BUTTON_RIGHT
                mouseButton = SDL_BUTTON_RIGHT
                if !(mouseButton in mouseButtons)
                    push!(mouseButtons, mouseButton)
                end
            end

            this.mouseButtons = mouseButtons
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end