module ParticleModule
    using ..JulGame

    export Particle
    mutable struct Particle
        currentFrame::Integer
        position::Math.Vector2f
        texture::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Texture}}

        function Particle()
            this = new()
            
        
            return this
        end
    end

    function Base.getproperty(this::Particle, s::Symbol)
        if s == :draw
            function()

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
