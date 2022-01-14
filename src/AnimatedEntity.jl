__precompile__()
include("Math/Vector2f.jl")
include("Entity.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct AnimatedEntity
    frames
    lastFrame
    lastUpdate
    numFrames
        
    #frames: number of frames in an animation
    #width: width of each frame
    function AnimatedEntity(frameCount, width)
        this = new()
        #this.frames = Array{Int64, frameCount}
        this.lastFrame = 0
        this.lastUpdate = SDL_GetTicks()
        return this
    end
end

function Base.getproperty(this::AnimatedEntity, s::Symbol)
    if s == :method0
        function()
            #
        end
    elseif s == :method1
        function()
            #SDL_DestroyRenderer(this.renderer)
        end
    else
        getfield(this, s)
    end
end