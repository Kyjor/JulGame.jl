__precompile__()
include("Math/Vector2f.jl")
include("Entity.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct AnimatedEntity
    renderer 
    window

    height
    width

    function AnimatedEntity(title, width, height)
        this = new()
       
        this.height = height
        return this
    end
end

function Base.getproperty(this::AnimatedEntity, s::Symbol)
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
        end
    elseif s == :display
        function()
            SDL_RenderPresent(this.renderer)
        end
    else
        getfield(this, s)
    end
end