__precompile__()
include("Math/Vector2f.jl")
include("Entity.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct Sprite
    frameCount
    image
    lastFrame
    lastUpdate
    offset
    parent
    position
    renderer
    texture
    
    #frames: number of frames in an animation
    #width: width of each frame
    function Sprite(frameCount, image, renderer)
        this = new()
        
        this.frameCount = frameCount
        this.image = IMG_Load(image)
        this.lastFrame = 0
        this.lastUpdate = SDL_GetTicks()
        this.parent = parent
        this.renderer = renderer
        this.texture = SDL_CreateTextureFromSurface(this.renderer, this.image)
        this.position = Vector2f(0.0, 0.0)
        return this
    end
end

function Base.getproperty(this::Sprite, s::Symbol)
    if s == :draw
        function(src, dest)
            SDL_RenderCopy(this.renderer, this.texture, src, Ref(SDL_Rect(this.parent.getTransform().getPosition().x,this.parent.getTransform().getPosition().y,64,64)))
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
    elseif s == :update
        function()
            #return this.frameCount
        end
   elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    else
        getfield(this, s)
    end
end