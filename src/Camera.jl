mutable struct Camera
    dimensions
    offset
    position
    target

    function Camera(dimensions::Vector2f, initialPosition::Vector2f, offset::Vector2f,target)
        this = new()
        
        this.dimensions = dimensions
        this.position = initialPosition
        this.offset = Vector2f(offset.x, offset.y)
        this.target = target
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
            if this.target != C_NULL
                targetPos = this.target.getPosition()
                this.position = Vector2f(targetPos.x - (this.dimensions.x/SCALE_UNITS/2) + this.offset.x, targetPos.y - (this.dimensions.y/SCALE_UNITS/2) + this.offset.y)
            end
        end
    elseif s == :setTarget
        function(target)
            this.target = target
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end