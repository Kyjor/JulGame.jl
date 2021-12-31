__precompile__()
include("Math/Vector2f.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Entity
    position::Vector2f
    texture
    currentFrame
    
    Entity(position::Vector2f, texture, currentFrame) = new(position,texture,currentFrame)

    function getCurrentFrame()
        return currentFrame
    end
    function getPosition()
        return position
    end
    function getTexture()
        return texture
    end

end   
