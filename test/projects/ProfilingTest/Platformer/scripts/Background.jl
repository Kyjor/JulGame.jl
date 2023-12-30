using JulGame 

mutable struct Background
    parent

    function Background()
        this = new()

        this.parent = C_NULL

        return this
    end
end

function Base.getproperty(this::Background, s::Symbol)
    if s == :initialize
        function()
        end
    elseif s == :update
        function(deltaTime)
            this.parent.getTransform().position = JulGame.Math.Vector2f(MAIN.scene.camera.position.x + 9.5, 0)
        end
    elseif s == :setParent 
        function(parent)
            this.parent = parent
        end
    elseif s == :onShutDown
        function ()
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end