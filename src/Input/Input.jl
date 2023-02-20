include("Button.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Input
    quit::Bool
    buttons::Array{Button}

    function Input()
        this = new()

        this.quit = false
        this.buttons = []

        return this
    end
end

function Base.getproperty(this::Input, s::Symbol)
    if s == :pollInput
        function()
            
            event_ref = Ref{SDL_Event}()
            while Bool(SDL_PollEvent(event_ref))
                evt = event_ref[]
                
                if evt.type == SDL_QUIT
                    this.quit = true
                    return -1
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
        getfield(this, s)
    end
end