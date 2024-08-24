module AnimatorModule
    using ..Component.AnimationModule
    using ..Component.JulGame
    using ..Component.JulGame.Math
    using ..Component.SpriteModule
    import ..Component
    export Animator
    struct Animator
        animations::Vector{Animation}
    end

    export InternalAnimator
    mutable struct InternalAnimator
        animations::Vector{Animation}
        currentAnimation::Animation
        lastFrame::Int32
        lastUpdate::UInt64
        parent::Any
        playOnce::Bool
        sprite::Union{InternalSprite, Ptr{Nothing}}

        function InternalAnimator(parent::Any, animations::Vector{Animation} = Animation[])
            this = new()
            
            this.animations = animations
            this.currentAnimation = length(this.animations) > 0 ? this.animations[1] : C_NULL
            this.lastFrame = 1
            this.lastUpdate = SDL2.SDL_GetTicks()
            this.parent = parent
            this.sprite = C_NULL
            this.playOnce = false

            return this
        end
    end

    function Component.get_last_update(this::InternalAnimator)
        return this.lastUpdate
    end

    function Component.set_last_update(this::InternalAnimator, value)
        this.lastUpdate = value
    end

    function Component.update(this::InternalAnimator, currentRenderTime, deltaTime)
        Update(this, currentRenderTime, deltaTime)
    end

    function Component.set_sprite(this::InternalAnimator, sprite)
        this.sprite = sprite
    end

    function Component.set_parent(this::InternalAnimator, parent)
        this.parent = parent
    end

    function Component.append_array(this::InternalAnimator)
        push!(this.animations, Animation([Math.Vector4(0,0,0,0)], Int32(60)))
    end
    
    function Component.play_animation_once(this::InternalAnimator, animationIndex::Int)
        if animationIndex > 0 && animationIndex <= length(this.animations)
            this.currentAnimation = this.animations[animationIndex]
            this.playOnce = true
            this.lastFrame = 1

            return
        end

        @warn "Animation index out of bounds"
    end
    
    
    """
    ForceFrameUpdate(this::InternalAnimator, frameIndex::Int32)
    
    Updates the sprite crop of the animator to the specified frame index.
    
    # Arguments
    - `this::InternalAnimator`: The animator object.
    - `frameIndex::Int32`: The index of the frame to update the sprite crop to.
    
    # Example
    ```
    animator = Animator([Animation([Math.Vector4(0,0,0,0)], 60)])
    ForceFrameUpdate(animator, 1)
    ```
    """
    function ForceFrameUpdate(this::InternalAnimator, frameIndex::Int32)
        this.sprite.crop = this.currentAnimation.frames[frameIndex]
    end
    export ForceFrameUpdate

    """
    Update(this::Animator, currentRenderTime::UInt64, deltaTime::UInt64)

    Updates the animator object.

    # Arguments
    - `this::Animator`: The animator object.
    - `currentRenderTime::UInt64`: The current render time.
    - `deltaTime::UInt64`: The time since the last update.

    # Example
    ```
    animator = Animator([Animation([Math.Vector4(0,0,0,0)], 60)])
    Update(animator, SDL2.SDL_GetTicks(), 1000)
    ```
    """
    function Update(this::InternalAnimator, currentRenderTime, deltaTime)
        if this.currentAnimation.animatedFPS < 1 || (this.playOnce && this.lastFrame == length(this.currentAnimation.frames))
            return
        end
        deltaTime = (currentRenderTime - Component.get_last_update(this)) / 1000.0
        framesToUpdate = floor(deltaTime / (1.0 / this.currentAnimation.animatedFPS))
        if framesToUpdate > 0
            this.lastFrame = this.lastFrame + framesToUpdate
            Component.set_last_update(this, currentRenderTime)
        end
        this.sprite.crop = this.currentAnimation.frames[this.lastFrame > length(this.currentAnimation.frames) ? (1; this.lastFrame = 1) : this.lastFrame]
    end
    
end
