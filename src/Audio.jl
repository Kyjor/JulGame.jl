using SimpleDirectMediaLayer.LibSDL2

mutable struct Audio
    
    function Audio()
        this = new()
        
        return this
    end
end

function Base.getproperty(this::Audio, s::Symbol)
    if s == :playSoundOnce
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