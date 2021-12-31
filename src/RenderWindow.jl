__precompile__()
include("Math/Vector2f.jl")
include("Entity.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct RenderWindow
    renderer 
    window

    height
    width

    function RenderWindow(title, width, height)
        this = new()
        this.window = SDL_CreateWindow(title, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, width, height, SDL_WINDOW_SHOWN)
        @assert this.window != nothing "error initializing SDL Window: $(unsafe_string(SDL_GetError()))"
        SDL_SetWindowResizable(this.window, SDL_TRUE)
        
        this.renderer = SDL_CreateRenderer(this.window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC)
        this.width = width
        this.height = height
        return this
    end
end

function Base.getproperty(this::RenderWindow, s::Symbol)
    if s == :loadTexture
        function(filePath)
            texture = IMG_LoadTexture(this.renderer, filePath)
            #TODO: check for texture load error
            @assert texture != nothing "error initializing SDL: $(unsafe_string(SDL_GetError()))"

            return texture
        end
    elseif s == :cleanUp
        function()
            SDL_DestroyRenderer(this.renderer)
        end
    elseif s == :clear
        function()
            SDL_RenderClear(this.renderer)
        end
    elseif s == :render
        function(entity::Entity)
            src = SDL_Rect(entity.getCurrentFrame().x, entity.getCurrentFrame().y, entity.getCurrentFrame().w, entity.getCurrentFrame().h)
            dst = SDL_Rect(entity.getPosition().x * 4, entity.getPosition().y * 4, entity.getCurrentFrame().w * 4, entity.getCurrentFrame().h * 4)
        
            SDL_RenderCopy(this.renderer, entity.getTexture(), Ref(src), Ref(dst))
            SDL_Delay(1000 ÷ 60)
        end
    elseif s == :display
        function()
            SDL_RenderPresent(this.renderer)
        end
    else
        getfield(this, s)
    end
end