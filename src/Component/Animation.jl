module AnimationModule 
using SimpleDirectMediaLayer.LibSDL2
using ..Component.engine

export Animation
mutable struct Animation
    animatedFPS::Int64
    #currentFrame
    frames::Array{Math.Vector4}
    lastFrame
    lastUpdate
    parent
    sprite

    function Animation(frames, animatedFPS)
        this = new()
        
        this.animatedFPS = animatedFPS
        this.frames = frames
        this.lastFrame = 0
        this.lastUpdate = SDL_GetTicks()
        this.parent = C_NULL
        this.sprite = C_NULL

        return this
    end
end

function Base.getproperty(this::Animation, s::Symbol)
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
            if length(this.frames) == 1
                return
            end
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
            this.parent = parent
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end
end
