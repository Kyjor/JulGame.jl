__precompile__()
using SimpleDirectMediaLayer.LibSDL2

mutable struct Input
    quit::Bool
    scan_code
    #Keys
    # KEY_A
    # KEY_B
    # KEY_C
    # KEY_D
    # KEY_E
    # KEY_F
    # KEY_G
    # KEY_H
    # KEY_I
    # KEY_J
    # KEY_K
    # KEY_L
    # KEY_M
    # KEY_N
    # KEY_O
    # KEY_P
    # KEY_Q
    # KEY_R
    # KEY_S
    # KEY_T
    # KEY_U
    # KEY_V
    # KEY_W
    # KEY_X
    # KEY_Y
    # KEY_Z
    # KEY_LEFT
    # KEY_RIGHT
    # KEY_DOWN
    # KEY_UP
    function Input()
        this = new()
        this.quit = false
        this.scan_code = nothing

        return this
    end
end

function Base.getproperty(this::Input, s::Symbol)
    if s == :pollInput
        function(event_ref)
            while Bool(SDL_PollEvent(event_ref))
                evt = event_ref[]
                evt_ty = evt.type
                if evt_ty == SDL_QUIT
                    this.quit = true
                    return -1
                    break
                elseif evt_ty == SDL_KEYDOWN
                    this.scan_code = evt.key.keysym.scancode
                    break
                else
                    this.scan_code = nothing
                    break
                end
            end
        end
    elseif s == :method0
        function()
            return nothing
        end
    else
        getfield(this, s)
    end
end