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
        currentAnimation::Union{Animation, Nothing}
        lastFrame::Int
        lastUpdate::UInt64
        parent::Any
        playOnce::Bool
        sprite::Union{InternalSprite, Nothing}

        function InternalAnimator(parent::Any, animations::Vector{Animation} = Animation[])
            this = new()
            
            this.animations = animations
            this.currentAnimation = length(this.animations) > 0 ? this.animations[1] : nothing
            this.lastFrame = 0
            this.lastUpdate = SDL2.SDL_GetTicks()
            this.parent = parent
            this.sprite = nothing
            this.playOnce = false

            return this
        end
    end

    function Component.update(this::InternalAnimator, currentRenderTime, deltaTime)
        if this.currentAnimation === nothing || this.currentAnimation.animatedFPS < 1 || this.sprite == nothing
            return
        end
        frameCount = isempty(this.currentAnimation.framePaths) ?
            length(this.currentAnimation.frames) :
            length(this.currentAnimation.framePaths)
        if frameCount == 0 || (this.playOnce && this.lastFrame == frameCount)
            return
        end

        deltaTime = (currentRenderTime - this.lastUpdate) / 1000.0
        framesToUpdate = floor(Int, deltaTime / (1.0 / this.currentAnimation.animatedFPS))
        if this.lastFrame == 0
            this.lastFrame = 1
            this.lastUpdate = currentRenderTime
        elseif framesToUpdate > 0
            this.lastFrame = this.lastFrame + framesToUpdate
            this.lastUpdate = currentRenderTime
        end
        if this.lastFrame > frameCount
            this.lastFrame = this.playOnce ?
                frameCount :
                ((this.lastFrame - 1) % frameCount) + 1
        end

        if !isempty(this.currentAnimation.framePaths)
            this.sprite.imagePath = this.currentAnimation.framePaths[this.lastFrame]
        end
        if !isempty(this.currentAnimation.frames)
            frameIndex = min(this.lastFrame, length(this.currentAnimation.frames))
            this.sprite.crop = this.currentAnimation.frames[frameIndex]
        end
    end

    function Component.append_array(this::InternalAnimator)
        push!(this.animations, Animation([Math.Vector4(0,0,0,0)], 60))
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

    function Component.duplicate(this::InternalAnimator, parent::Any)
        newAnimator = InternalAnimator(parent, this.animations)
        newAnimator.currentAnimation = this.currentAnimation
        newAnimator.lastFrame = this.lastFrame
        newAnimator.lastUpdate = this.lastUpdate
        newAnimator.playOnce = this.playOnce
        newAnimator.sprite = this.sprite

        return newAnimator
    end
    
    
    """
    force_frame_update(this::InternalAnimator, frameIndex::Int)
    
    Updates the sprite crop of the animator to the specified frame index.
    
    # Arguments
    - `this::InternalAnimator`: The animator object.
    - `frameIndex::Int`: The index of the frame to update the sprite crop to.
    
    # Example
    ```
    animator = Animator([Animation([Math.Vector4(0,0,0,0)], 60)])
    force_frame_update(animator, 1)
    ```
    """
    function force_frame_update(this::InternalAnimator, frameIndex::Int)
        @warn "test"
        if this.currentAnimation === nothing || this.sprite === nothing
            return
        end
        if !isempty(this.currentAnimation.framePaths)
            this.sprite.imagePath = this.currentAnimation.framePaths[frameIndex]
        end
        if !isempty(this.currentAnimation.frames)
            this.sprite.crop = this.currentAnimation.frames[frameIndex]
        end
        this.lastFrame = frameIndex
    end
    export force_frame_update    
end
