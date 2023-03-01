include("Button.jl")
include("../SceneInstance.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct Input
    buttons::Array{Button}
    debug::Bool
    quit::Bool

    function Input()
        this = new()

        this.debug = false
        this.buttons = []
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
                    if SceneInstance.screenButtons != C_NULL
                        x,y = Int[1], Int[1]
                        SDL_GetMouseState(pointer(x), pointer(y))

                        for screenButton in SceneInstance.screenButtons
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
                            #screenButton.render()
                        end
                    end
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
            
            if windowEvent == SDL_WINDOWEVENT_SHOWN
                println(string("Window %d shown", event.window.windowID))
            elseif windowEvent == SDL_WINDOWEVENT_HIDDEN
                println(string("Window %d hidden", event.window.windowID))
            elseif windowEvent == SDL_WINDOWEVENT_EXPOSED
                println(string("Window %d exposed", event.window.windowID))
            elseif windowEvent == SDL_WINDOWEVENT_MOVED
                println(string("Window %d moved to %d,%d",
                        event.window.windowID, event.window.data1,
                        event.window.data2))
            elseif windowEvent == SDL_WINDOWEVENT_RESIZED
                println(string("Window %d resized to %dx%d",
                        event.window.windowID, event.window.data1,
                        event.window.data2))
            elseif windowEvent == SDL_WINDOWEVENT_SIZE_CHANGED
                println(string("Window %d size changed to %dx%d",
                        event.window.windowID, event.window.data1,
                        event.window.data2))
            elseif windowEvent == SDL_WINDOWEVENT_MINIMIZED
                println(string("Window %d minimized", event.window.windowID))
            elseif windowEvent == SDL_WINDOWEVENT_MAXIMIZED
                println(string("Window %d maximized", event.window.windowID))
            elseif windowEvent == SDL_WINDOWEVENT_RESTORED
                println(string("Window %d restored", event.window.windowID))
            elseif windowEvent == SDL_WINDOWEVENT_ENTER
                println(string("Mouse entered window %d", event.window.windowID))
            elseif windowEvent == SDL_WINDOWEVENT_LEAVE
                println(string("Mouse left window %d", event.window.windowID))
            elseif windowEvent == SDL_WINDOWEVENT_FOCUS_GAINED
                println(string("Window %d gained keyboard focus", event.window.windowID))
            elseif windowEvent == SDL_WINDOWEVENT_FOCUS_LOST
                println(string("Window %d lost keyboard focus", event.window.windowID))
            elseif windowEvent == SDL_WINDOWEVENT_CLOSE
                println(string("Window %d closed", event.window.windowID))
            elseif windowEvent == SDL_WINDOWEVENT_TAKE_FOCUS
                println(string("Window %d is offered a focus", event.window.windowID))
            elseif windowEvent == SDL_WINDOWEVENT_HIT_TEST
                println(string("Window %d has a special hit test", event.window.windowID))
            else
                println(string("Window %d got unknown event %d", event.window.windowID, event.window.event))   
            end    
        end
    elseif s == :handleKeyEvent
        function(keyboardState)
            buttons = []
            button = Button_None::Button

            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_W, SDL_SCANCODE_UP])
                button = Button_Up::Button
                if !(button in buttons)
                    push!(buttons, button)
                end
            end
            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_A, SDL_SCANCODE_LEFT])
                button = Button_Left::Button
                if !(button in buttons)
                    push!(buttons, button)
                end
            end
            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_S, SDL_SCANCODE_DOWN])
                button = Button_Down::Button
                if !(button in buttons)
                    push!(buttons, button)
                end
            end
            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_D, SDL_SCANCODE_RIGHT])
                button = Button_Right::Button
                if !(button in buttons)
                    push!(buttons, button)
                end
            end
            if this.checkScanCode(keyboardState, 1, [SDL_SCANCODE_SPACE])
                button = Button_Jump::Button
                if !(button in buttons)
                    push!(buttons, button)
                end
            end

            this.buttons = buttons
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end