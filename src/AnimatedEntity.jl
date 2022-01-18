__precompile__()
include("Math/Vector2f.jl")
include("Entity.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct AnimatedEntity
    frames
    image
    lastFrame
    lastUpdate
    numFrames
    position
    renderer
    
    #frames: number of frames in an animation
    #width: width of each frame
    function AnimatedEntity(renderer, frameCount, width)
        this = new()
        #this.frames = Array{Int64, frameCount}
        this.lastFrame = 0
        this.lastUpdate = SDL_GetTicks()
        this.renderer = renderer
        return this
    end
end

function Base.getproperty(this::AnimatedEntity, s::Symbol)
    if s == :draw
        function()
            
        end
    elseif s == :method1
        function()
            #SDL_DestroyRenderer(this.renderer)
        end
    else
        getfield(this, s)
    end
end