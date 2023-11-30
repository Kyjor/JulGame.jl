module DotModule
    using ..JulGame

    export Dot
    mutable struct Dot
        dimensions::Math.Vector2f
        offset::Math.Vector2f
        maximumVelocity::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2.SDL_Texture}}

        function Dot()
            this = new()
        
            return this
        end
    end

    function Base.getproperty(this::Dot, s::Symbol)
        if s == :draw
            function()

            end
        elseif s == :draw
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