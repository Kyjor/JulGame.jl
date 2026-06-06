export {}

    // using ..Component.JulGame
    // import ..Component
    
    class JulGameAnimation {
        animatedFPS: number
        frames: Vector4[]

        constructor(frames: Vector4[], animatedFPS: number) {
            // Convert animatedFPS to Int32
            animatedFPS = animatedFPS
            
            
            this.animatedFPS = animatedFPS
            this.frames = frames

        }
    }
export { JulGameAnimation }
