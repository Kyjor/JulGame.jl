__precompile__()
include("Math/Vector2f.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Collider
   collider
   
   width
   height
   tag
    
    function Collider(position, texture)
        this = new()

        this.position = position
        this.texture = texture
        this.currentFrame = Ref(SDL_Rect(0, 0, 32, 32))

        return this
    end
end

function Base.getproperty(this::Collider, s::Symbol)
    if s == :getPosition
        function()
            return this.position
        end
    elseif s == :setPosition
        function(position::Vector2f)
            this.position = position
        end
    elseif s == :getTexture
        function()
            return this.texture
        end
    elseif s == :getCurrentFrame
        function()
           return this.currentFrame.x
        end
    else
        getfield(this, s)
    end
end