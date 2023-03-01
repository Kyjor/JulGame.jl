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