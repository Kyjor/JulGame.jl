include("../../../src/Macros.jl")
include("../../../src/SceneInstance.jl")

mutable struct GameManager

    function GameManager()
        this = new()
        

        return this
    end
end

function Base.getproperty(this::GameManager, s::Symbol)
    if s == :initialize
        function()
        end
    elseif s == :update
        function(deltaTime)
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end