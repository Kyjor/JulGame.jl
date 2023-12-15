module AnimatorModule
    using ..Component.AnimationModule
    using ..Component.JulGame
    using ..Component.JulGame.Math

    export Animator
    mutable struct Animator
        animations::Array{Animation}
        currentAnimation::Animation
        lastFrame::Integer
        lastUpdate::UInt64
        parent::Any
        sprite::Any

        function Animator(animations = [])
            this = new()
            
            this.animations = animations
            this.currentAnimation = length(this.animations) > 0 ? this.animations[1] : C_NULL
            this.lastFrame = 1
            this.lastUpdate = SDL2.SDL_GetTicks()
            this.parent = C_NULL
            this.sprite = C_NULL

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

    
    """
    ForceSpriteUpdate(this::Animator, frameIndex::Integer)
    
    Updates the sprite crop of the animator to the specified frame index.
    
    # Arguments
    - `this::Animator`: The animator object.
    - `frameIndex::Integer`: The index of the frame to update the sprite crop to.
    
    # Example
    ```
    animator = Animator([Animation([Math.Vector4(0,0,0,0)], 60)])
    ForceSpriteUpdate(animator, 1)
    ```
    """
    function ForceSpriteUpdate(this::Animator, frameIndex::Integer)
        this.sprite.crop = this.currentAnimation.frames[frameIndex]
    end
    export ForceSpriteUpdate
end