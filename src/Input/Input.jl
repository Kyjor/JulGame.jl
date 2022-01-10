__precompile__()
using SimpleDirectMediaLayer.LibSDL2

mutable struct Input
    quit::Bool
    scan_code
    mouseX::Integer
    mouseY::Integer
    
    function Input()
        this = new()
        this.quit = false
        this.scan_code = nothing
        this.mouseX = 0
        this.mouseY = 0
        
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