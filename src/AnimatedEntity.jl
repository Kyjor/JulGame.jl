__precompile__()
include("Math/Vector2f.jl")
include("Entity.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct AnimatedEntity
    frameCount
    image
    lastFrame
    lastUpdate
    position
    renderer
    texture
    
    #frames: number of frames in an animation
    #width: width of each frame
    function AnimatedEntity(frameCount, image, renderer)
        this = new()
        
        this.frameCount = frameCount
        this.image = IMG_Load(image)
        this.lastFrame = 0
        this.lastUpdate = SDL_GetTicks()
        this.renderer = renderer
        this.texture = SDL_CreateTextureFromSurface(this.renderer, this.image)
        return this
    end
end

function Base.getproperty(this::AnimatedEntity, s::Symbol)
    if s == :draw
        function(src, dest)
            SDL_RenderCopy(this.renderer, this.texture, src, dest)
        end
    elseif s == :getLastFrame
        function()
            return this.lastFrame
        end
    elseif s == :setLastFrame
        function(value)
            this.lastFrame = value
        end
    elseif s == :getLastUpdate
        function()
            return this.lastUpdate
        end
    elseif s == :setLastUpdate
        function(value)
            this.lastUpdate = value
        end
    elseif s == :getFrameCount
        function()
            return this.frameCount
        end
    else
        getfield(this, s)
    end
end