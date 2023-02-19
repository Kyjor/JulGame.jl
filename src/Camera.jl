mutable struct Camera
    parent

    function Camera()
        this = new()
        
        this.parent = C_NULL
        this.initialize()

        return this
    end
end

function Base.getproperty(this::Camera, s::Symbol)
    if s == :initialize
        function()
        end
    elseif s == :update
        function()
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    else
        getfield(this, s)
    end
end