export {}

    // using ..Component.JulGame
    // import ..Component
    
    class JulGameAnimation {
        animatedFPS: number
        frames: Vector4[]
        framePaths: string[]

        constructor(
            frames: Vector4[],
            animatedFPS: number,
            framePaths: string[] = [],
        ) {
            // Convert animatedFPS to Int32
            this.animatedFPS = animatedFPS
            this.frames = frames
            this.framePaths = framePaths

        }
    }
export { JulGameAnimation }
