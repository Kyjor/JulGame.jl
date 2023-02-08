include("../../../src/Script.jl")

mutable struct PlayerMovement
    parent

    function PlayerMovement()
        this = new()
        
        this.parent = C_NULL
        this.initialize()

        return this
    end
end

function Base.getproperty(this::PlayerMovement, s::Symbol)
    if s == :initialize
        function()
        end
    elseif s == :update
        function()
            println(string("Script of type: ", typeof(this), " is updating "))
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    else
        getfield(this, s)
    end
end