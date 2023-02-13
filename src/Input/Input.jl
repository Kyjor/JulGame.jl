include("Button.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Input
    quit::Bool
    scan_code
    keyup
    mouseX::Integer
    mouseY::Integer
    buttons::Array{Button}

    function Input()
        this = new()

        this.quit = false
        this.scan_code = nothing
        this.keyup = nothing
        this.mouseX = 0
        this.mouseY = 0
        this.buttons = []

        return this
    end
end

function Base.getproperty(this::Input, s::Symbol)
    if s == :pollInput
        function()
            event_ref = Ref{SDL_Event}()
            while Bool(SDL_PollEvent(event_ref))
                x,y = Int[1], Int[1]
                SDL_GetMouseState(pointer(x), pointer(y))
                #this.mouseX = x
                #   this.mouseY = y
                
                evt = event_ref[]
                evt_ty = evt.type
                if evt_ty == SDL_QUIT
                    this.quit = true
                    return -1
                elseif evt_ty == SDL_KEYDOWN || evt_ty == SDL_KEYUP
                    this.scan_code = evt.key.keysym.scancode
                    this.handleKeyEvent(evt.key, evt_ty)
                    break
                elseif evt_ty == SDL_KEYUP
                    this.keyup = evt.key.keysym.scancode
                    break
                else
                    this.scan_code = nothing
                    break
                end
            end
        end
    elseif s == :handleKeyEvent
        function(e, ety)
            scan_code = e.keysym.scancode
            buttons = []
            button = Button_None::Button

            if scan_code == SDL_SCANCODE_W || scan_code == SDL_SCANCODE_UP
                button = Button_Up::Button
            elseif scan_code == SDL_SCANCODE_A || scan_code == SDL_SCANCODE_LEFT
                button = Button_Left::Button
            elseif scan_code == SDL_SCANCODE_S || scan_code == SDL_SCANCODE_DOWN
                button = Button_Down::Button
            elseif scan_code == SDL_SCANCODE_D || scan_code == SDL_SCANCODE_RIGHT
                button = Button_Right::Button
            elseif scan_code == SDL_SCANCODE_SPACE
                button = Button_Jump::Button
            end

            for interactedButton in this.buttons
                if interactedButton == button && ety == SDL_KEYUP
                    # println("skipping button to remove it")
                elseif !(interactedButton in buttons)
                    push!(buttons, interactedButton)
                end
            end
            if ety != SDL_KEYUP && !(button in buttons)
                push!(buttons, button)
            end

            this.buttons = buttons
        end
    else
        getfield(this, s)
    end
end