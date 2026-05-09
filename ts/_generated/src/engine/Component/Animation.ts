export {}

    // using ..Component.JulGame
    // import ..Component
    
    class JulGameAnimation {
        animatedFPS: number
        frames: Vector4[]

        constructor(frames: Vector4[],  animatedFPS: number) {
            // Convert animatedFPS to Int32
            animatedFPS = TypeConversions.safe_int32_convert(animatedFPS)
            
            
            this.animatedFPS = animatedFPS
            this.frames = frames

        }
    }

