module CameraModule
    using ..JulGame
    using .Math

    export Camera
    mutable struct Camera
		backgroundColor::NTuple{4, Int}
        offset::Vector2f
        position::Vector3f
        size::Vector2
        yaw::Float64
        pitch::Float64
        target::Union{
            Ptr{Nothing}, 
            JulGame.TransformModule.Transform
            }
        windowPos::Vector2

        function Camera(size::Vector2, initialPosition::Vector3f, offset::Vector2f, target)
            this = new()
            
            this.backgroundColor = (0,0,0, 255)
            this.size = size
            this.position = initialPosition
            this.offset = Vector2f(offset.x, offset.y)
            this.target = target
            this.windowPos = Vector2(0,0)
            this.yaw = 0.0
            this.pitch = 0.0

            return this
        end
    end

    function update(this::Camera, newPosition::Union{Nothing, Vector3f} = nothing)
        SDL2.SDL_SetRenderDrawBlendMode(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, SDL2.SDL_BLENDMODE_BLEND)
        rgba = (r = Ref(UInt8(0)), g = Ref(UInt8(0)), b = Ref(UInt8(0)), a = Ref(UInt8(255)))
        SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r, rgba.g, rgba.b, rgba.a)
        SDL2.SDL_SetRenderDrawColor(Renderer, this.backgroundColor[1], this.backgroundColor[2], this.backgroundColor[3], this.backgroundColor[4]);
        SDL2.SDL_RenderFillRectF(Renderer, Ref(SDL2.SDL_FRect(this.windowPos.x, this.windowPos.y, this.size.x, this.size.y)))
        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[]);
        
        center_pixels = Vector2f(this.size.x / 2, this.size.y / 2)
        center_world = center_pixels / SCALE_UNITS

        if this.target !== nothing && this.target !== C_NULL && newPosition === nothing
            targetPos::Vector3f = this.target.position
            targetScale::Vector2f = this.target.scale
            this.position = Vector3f(targetPos.x - center_world.x + 0.5 * targetScale.x + this.offset.x,
                                     targetPos.y - center_world.y + 0.5 * targetScale.y + this.offset.y, 
                                     targetPos.z)
            return
        end

        if newPosition !== nothing
            this.position = newPosition
        end
    end

    # making set property observable
    function Base.setproperty!(this::Camera, s::Symbol, x)
        @debug("setting camera property $(s) to: $(x)")
        try
            setfield!(this, s, x)
        catch e
            println(e)
        end
    end
end
