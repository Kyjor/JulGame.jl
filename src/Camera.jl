using JulGame
using .Math
import JulGame: deprecated_get_property
import JulGame.Component

mutable struct Camera
    dimensions::Vector2
    offset::Vector2f
    position::Vector2f
    startingCoordinates::Vector2f

    target::Union{
        Ptr{Nothing}, 
        # JulGame.EntityModule.Entity,
        JulGame.TransformModule.Transform
        }
    windowPos::Vector2

    function Camera(dimensions::Vector2, initialPosition::Vector2f, offset::Vector2f, target)
        this = new()
        
        this.dimensions = dimensions
        this.position = initialPosition
        this.offset = Vector2f(offset.x, offset.y)
        this.target = target
        this.startingCoordinates = Vector2f()                                                                                                                                                                                                           
        this.windowPos = Vector2(0,0)
        this.initialize()

        return this
    end
end

function Base.getproperty(this::Camera, s::Symbol)
    method_props = (
        initialize = initialize,
        update = update,
        setTarget = set_target
    )
    return deprecated_get_property(method_props, this, s)
end

function initialize(this::Camera)
end

function update(this::Camera, newPosition = C_NULL)
    SDL2.SDL_SetRenderDrawColor(Renderer, MAIN.cameraBackgroundColor[1], MAIN.cameraBackgroundColor[2], MAIN.cameraBackgroundColor[3], SDL2.SDL_ALPHA_OPAQUE);
    SDL2.SDL_RenderFillRectF(Renderer, Ref(SDL2.SDL_FRect(this.windowPos.x, this.windowPos.y, this.dimensions.x, this.dimensions.y)))

    if this.target != C_NULL && newPosition == C_NULL
        targetPos = this.target.position
        center =  Vector2f(this.dimensions.x/SCALE_UNITS/2, this.dimensions.y/SCALE_UNITS/2)
        targetScale = this.target.scale
        this.position = targetPos - center + 0.5 * targetScale + this.offset
        return
    end
    if newPosition == C_NULL
        return
    end
    this.position = newPosition
end

function set_target(this::Camera, target)
    this.target = target
end
