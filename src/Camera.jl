global const SCALE_UNITS = Ref{Float64}(64.0)[]

mutable struct Camera
    dimensions
    offset
    position::Vector2f
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
        function(newPosition = C_NULL)
            if this.target != C_NULL && newPosition == C_NULL
                targetPos = this.target.getPosition()
                this.position = Vector2f(targetPos.x - (this.dimensions.x/SCALE_UNITS/2) + this.offset.x, targetPos.y - (this.dimensions.y/SCALE_UNITS/2) + this.offset.y)
                return
            end
            this.position = newPosition
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