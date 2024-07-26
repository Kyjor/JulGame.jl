using JulGame 

mutable struct Water
    main
    offset
    parent
    
    function Water()
        this = new()

        this.parent = C_NULL
        this.offset = JulGame.Math.Vector2f(0, 0)

        return this
    end
end

function Base.getproperty(this::Water, s::Symbol)
    if s == :initialize
        function(main)
            this.offset = JulGame.Math.Vector2f(this.parent.transform.position.x + 9, 5.5)
            this.main = main
        end
    elseif s == :update
        function(deltaTime)
            this.parent.transform.position = JulGame.Math.Vector2f(this.main.scene.camera.position.x, 0) + this.offset
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
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end
end