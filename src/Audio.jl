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
        getfield(this, s)
    end
end