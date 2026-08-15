export {}
import { InternalSprite } from "./Sprite";


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
        currentAnimation: JulGameAnimation | null
        lastFrame: number
        lastUpdate: number
        parent: any
        playOnce: boolean
        sprite: InternalSprite | null

        constructor(parent: any, animations: JulGameAnimation[] = []) {
            
            
            this.animations = animations
            this.currentAnimation = this.animations.length > 0 ? this.animations[0] : null
            this.lastFrame = 0
            this.lastUpdate = (globalThis as any).JulGameSdl.glue_SDL_GetTicks()
            this.parent = parent
            this.sprite = null
            this.playOnce = false

        }
    }

    function Component_update(self: InternalAnimator, currentRenderTime: number) {
            if (self.currentAnimation === null || self.currentAnimation.animatedFPS < 1 || self.sprite === null) {
                return
            }
            let frameCount = isempty(self.currentAnimation.framePaths) ?
                self.currentAnimation.frames.length :
                self.currentAnimation.framePaths.length
            if (frameCount == 0 || (self.playOnce && self.lastFrame == frameCount)) {
                return
            }
    
            let deltaTime = (currentRenderTime - self.lastUpdate) / 1000.0
            let framesToUpdate = Math.floor(deltaTime / (1.0 / self.currentAnimation.animatedFPS))
            if (self.lastFrame == 0) {
                self.lastFrame = 1
                self.lastUpdate = currentRenderTime
            } else if (framesToUpdate > 0) {
                self.lastFrame = self.lastFrame + framesToUpdate
                self.lastUpdate = currentRenderTime
            }
            if (self.lastFrame > frameCount) {
                self.lastFrame = self.playOnce ?
                    frameCount :
                    ((self.lastFrame - 1) % frameCount) + 1
            }

        // Julia lastFrame is 1-based; JS arrays are 0-based.
        if (!isempty(self.currentAnimation.framePaths)) {
            self.sprite.imagePath = self.currentAnimation.framePaths[self.lastFrame - 1]
        }
        if (!isempty(self.currentAnimation.frames)) {
            let frameIndex = Math.min(self.lastFrame, self.currentAnimation.frames.length)
            self.sprite.crop = self.currentAnimation.frames[frameIndex - 1]
        }
    }

    
    function Component_play_animation_once(self: InternalAnimator, animationIndex: number) {
            if (animationIndex > 0 && animationIndex <= self.animations.length) {
                self.currentAnimation = self.animations[animationIndex - 1]
                self.playOnce = true
                self.lastFrame = 1
                return
            }
        console.warn("Animation index out of bounds")
    }

    function Component_duplicate(self: InternalAnimator, parent: any) {
        let newAnimator = new InternalAnimator(parent, self.animations)
        newAnimator.currentAnimation = self.currentAnimation
        newAnimator.lastFrame = self.lastFrame
        newAnimator.lastUpdate = self.lastUpdate
        newAnimator.playOnce = self.playOnce
        newAnimator.sprite = self.sprite

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
    let animator = Animator([JulGameAnimation([{x: 0, y: 0, z: 0, t: 0}], 60)])
    force_frame_update(animator, 1)
    ```
    */
    function force_frame_update(self: InternalAnimator, frameIndex: number) {
            if (self.currentAnimation === null || self.sprite === null) {
                return
            }
            if (!isempty(self.currentAnimation.framePaths)) {
                self.sprite.imagePath = self.currentAnimation.framePaths[frameIndex - 1]
            }
            if (!isempty(self.currentAnimation.frames)) {
                self.sprite.crop = self.currentAnimation.frames[frameIndex - 1]
            }
            self.lastFrame = frameIndex
    }
    
export { Animator, Component_duplicate, Component_play_animation_once, Component_update, InternalAnimator, force_frame_update }
