include("Math/Vector2f.jl")
include("Constants.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct Animator
    animatedFPS
    frameCount
    image
    lastFrame
    lastUpdate
    parent
    pixelsPerUnit
    position
    renderer
    texture
    sprite

    #frames: number of frames in an animation
    #width: width of each frame
    function Animator(frameCount, animatedFPS)
        this = new()
        
        this.frameCount = frameCount
        this.lastFrame = 0
        this.lastUpdate = SDL_GetTicks()
        this.animatedFPS = animatedFPS

        return this
    end
end

function Base.getproperty(this::Animator, s::Symbol)
    if s == :getLastFrame
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
        function(currentRenderTime, deltaTime)
            deltaTime = (currentRenderTime  - this.getLastUpdate()) / 1000.0
            framesToUpdate = floor(deltaTime / (1.0 / this.animatedFPS))
            if framesToUpdate > 0
                this.setLastFrame(this.getLastFrame() + framesToUpdate)
                this.setLastFrame(this.getLastFrame() % this.getFrameCount())
                this.setLastUpdate(currentRenderTime)
            end
            this.sprite.frameToDraw = this.getLastFrame()
        end
   elseif s == :setSprite
        function(sprite)
            println("set sprite")
            this.sprite = sprite
        end
    elseif s == :setParent
        function(parent)
            println("set parent")
            this.parent = parent
        end
    else
        getfield(this, s)
    end
end