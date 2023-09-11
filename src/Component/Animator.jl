module AnimatorModule
    using ..Component.AnimationModule
    using ..Component.JulGame
    using ..Component.JulGame.Math

    export Animator
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
            this.lastFrame = 1
            this.lastUpdate = SDL2.SDL_GetTicks()
            this.parent = C_NULL
            this.sprite = C_NULL

            return this
        end

        function Animator()
            this = new()
            
            this.animations = []
            this.lastFrame = 1
            this.lastUpdate = SDL2.SDL_GetTicks()

            return this
        end
    end

    function Base.getproperty(this::Animator, s::Symbol)
        if s == :getLastUpdate
            function()
                return this.lastUpdate
            end
        elseif s == :setLastUpdate
            function(value)
                this.lastUpdate = value
            end
        elseif s == :update
            function(currentRenderTime, deltaTime)
                if this.currentAnimation.animatedFPS < 1
                    return
                end
                deltaTime = (currentRenderTime - this.getLastUpdate()) / 1000.0
                framesToUpdate = floor(deltaTime / (1.0 / this.currentAnimation.animatedFPS))
                if framesToUpdate > 0
                    this.lastFrame = this.lastFrame + framesToUpdate
                    this.setLastUpdate(currentRenderTime)
                end
                this.sprite.crop = this.currentAnimation.frames[this.lastFrame > length(this.currentAnimation.frames) ? (1; this.lastFrame = 1) : this.lastFrame]
            end
        elseif s == :forceSpriteUpdate
            function(frameIndex)
                this.sprite.crop = this.currentAnimation.frames[frameIndex]
            end
    elseif s == :setSprite
            function(sprite)
                this.sprite = sprite
            end
        elseif s == :setParent
            function(parent)
                this.parent = parent
            end
        elseif s == :appendArray
            function()
                push!(this.animations, Animation([Math.Vector4(0,0,0,0)], 60))
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