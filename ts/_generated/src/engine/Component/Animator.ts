export {}
﻿
    // using ..Component.AnimationModule
    // using ..Component.JulGame
    // using ..Component.(globalThis as any).JulGame.Math
    // using ..Component.SpriteModule
    // import ..Component
    
    
    class Animator {
        animations: JulGameAnimation[]
    }

    
    class InternalAnimator {
        animations: JulGameAnimation[]
        currentAnimation: JulGameAnimation
        lastFrame: number
        lastUpdate: number
        parent: any
        playOnce: boolean
        sprite: InternalSprite | null

        constructor(parent: any,  animations: JulGameAnimation[] = JulGameAnimation[]) {
            
            
            this.animations = animations
            this.currentAnimation = this.animations.length > 0 ? this.animations[0] : null
            this.lastFrame = 0
            this.lastUpdate = (globalThis as any).JulGameSdl.glue_SDL_GetTicks()
            this.parent = parent
            this.sprite = null
            this.playOnce = false

        }
    }

    function Component_update(this: InternalAnimator,  currentRenderTime,  deltaTime) {
        if (this.currentAnimation.animatedFPS < 1 || (this.playOnce && this.lastFrame == this.currentAnimation.frames.length) || this.sprite == null || this.sprite === null) {
            return
        }
        deltaTime = (currentRenderTime - this.lastUpdate) / 1000.0
        let framesToUpdate = Math.floor(deltaTime / (1.0 / this.currentAnimation.animatedFPS))
        if (framesToUpdate > 0) {
            this.lastFrame = this.lastFrame + framesToUpdate
            this.lastUpdate = currentRenderTime
        }
        this.sprite.crop = this.currentAnimation.frames[this.lastFrame > this.currentAnimation.frames.length ? (1; this.lastFrame = 1) : this.lastFrame]
    }

    
    function Component_play_animation_once(this: InternalAnimator,  animationIndex: number) {
        if (animationIndex > 0 && animationIndex <= this.animations.length) {
            this.currentAnimation = this.animations[animationIndex]
            this.playOnce = true
            this.lastFrame = 1

            return
        }

        console.warn("Animation index out of bounds")
    }

    function Component_duplicate(this: InternalAnimator,  parent: any) {
        let newAnimator = InternalAnimator(parent, this.animations)
        newAnimator.currentAnimation = this.currentAnimation
        newAnimator.lastFrame = this.lastFrame
        newAnimator.lastUpdate = this.lastUpdate
        newAnimator.playOnce = this.playOnce
        newAnimator.sprite = this.sprite

        return newAnimator
    }
    
    
    /*
    force_frame_update(this: InternalAnimator, frameIndex: number)
    
    Updates the sprite crop of the animator to the specified frame index.
    
    // Arguments
    - `this: InternalAnimator`: The animator object.
    - `frameIndex: number`: The index of the frame to update the sprite crop to.
    
    // Example
    ```
    let animator = Animator([JulGameAnimation([Vector4(0,0,0,0)], 60)])
    force_frame_update(animator, 1)
    ```
    */
    function force_frame_update(this: InternalAnimator,  frameIndex: number) {
        frameIndex = frameIndex
        this.sprite.crop = this.currentAnimation.frames[frameIndex]
    }
    
