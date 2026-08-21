module AnimationModule 
    using ..Component.JulGame
    import ..Component
    export Animation
    mutable struct Animation
        animatedFPS::Int32
        frames::Vector{Math.Vector4}
        framePaths::Vector{String}

        function Animation(
            frames::Vector{Math.Vector4},
            animatedFPS::Int,
            framePaths::Vector{String} = String[],
        )
            # Convert animatedFPS to Int32
            animatedFPS = Math.TypeConversions.safe_int32_convert(animatedFPS)
            this = new()
            
            this.animatedFPS = animatedFPS
            this.frames = frames
            this.framePaths = framePaths

            return this
        end
    end
end
