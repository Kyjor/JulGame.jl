module CameraModule
    using JulGame
    using .Math

    export Camera
    mutable struct Camera
		backgroundColor::Tuple{Int64, Int64, Int64}
        offset::Vector2f
        position::Vector2f
        size::Vector2
        startingCoordinates::Vector2f

        target::Union{
            Ptr{Nothing}, 
            JulGame.TransformModule.Transform
            }
        windowPos::Vector2

        function Camera(size::Vector2, initialPosition::Vector2f, offset::Vector2f, target)
            this = new()
            
            this.backgroundColor = (0,0,0)
            this.size = size
            this.position = initialPosition
            this.offset = Vector2f(offset.x, offset.y)
            this.target = target
            this.startingCoordinates = Vector2f()                                                                                                                                                                                                           
            this.windowPos = Vector2(0,0)

            return this
        end
    end

    function update(this::Camera, newPosition)
        SDL2.SDL_SetRenderDrawColor(Renderer, this.backgroundColor[1], this.backgroundColor[2], this.backgroundColor[3], SDL2.SDL_ALPHA_OPAQUE);
        SDL2.SDL_RenderFillRectF(Renderer, Ref(SDL2.SDL_FRect(this.windowPos.x, this.windowPos.y, this.size.x, this.size.y)))

        if this.target != C_NULL && newPosition == C_NULL
            targetPos = this.target.position
            center =  Vector2f(this.size.x/SCALE_UNITS/2, this.size.y/SCALE_UNITS/2)
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

end