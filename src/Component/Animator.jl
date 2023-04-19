include("Animation.jl")

mutable struct Animator
    animations::Array{Animation}
    currentAnimation::Animation
    lastFrame::Int64
    lastUpdate
    parent
    sprite

    function Animator(animations)
        this = new()
        
        this.animations = animations
        this.currentAnimation = this.animations[1]
        #this.frameCount = frameCount
        this.lastFrame = 1
        this.lastUpdate = SDL_GetTicks()
        #this.animatedFPS = animatedFPS

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
            if value == 0 
                value = 1
            elseif value > length(this.currentAnimation.frames)
                value = length(this.currentAnimation.frames)
            end

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
            return length(this.currentAnimation.frames)
        end
    elseif s == :update
        function(currentRenderTime, deltaTime)
            deltaTime = (currentRenderTime - this.getLastUpdate()) / 1000.0
            framesToUpdate = floor(deltaTime / (1.0 / this.currentAnimation.animatedFPS))
            if framesToUpdate > 0
                this.lastFrame = this.lastFrame + framesToUpdate
                this.setLastUpdate(currentRenderTime)
            end
            this.sprite.crop = this.currentAnimation.frames[this.lastFrame > length(this.currentAnimation.frames) ? (1; this.lastFrame = 1) : this.lastFrame]
        end
   elseif s == :setSprite
        function(sprite)
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