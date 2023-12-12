using JulGame
using JulGame.Math

mutable struct Camera
    dimensions
    offset
    position::Vector2f
    target

    function Camera(dimensions::Vector2, initialPosition::Vector2f, offset::Vector2f,target)
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
            SDL2.SDL_SetRenderDrawColor(MAIN.renderer, MAIN.cameraBackgroundColor[1], MAIN.cameraBackgroundColor[2], MAIN.cameraBackgroundColor[3], SDL2.SDL_ALPHA_OPAQUE );
            SDL2.SDL_RenderFillRect(MAIN.renderer, Ref(SDL2.SDL_Rect(0,0,this.dimensions.x, this.dimensions.y)))

            if this.target != C_NULL && newPosition == C_NULL
                targetPos = this.target.getPosition()
                center =  Vector2f(this.dimensions.x/SCALE_UNITS/2, this.dimensions.y/SCALE_UNITS/2)
                targetScale = this.target.getScale()
                this.position = targetPos - center + 0.5 * targetScale + this.offset
                return
            end
            if newPosition == C_NULL
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