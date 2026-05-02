module CameraModule
    using ..JulGame
    using .Math
    using .Math: _Vector2, _Vector3

    export Camera, pixels_per_world_unit, apply_zoom_to_center!

    mutable struct Camera
        id::String
        name::String
		backgroundColor::NTuple{4, Int}
        offset::Vector2f
        position::Vector3f
        size::Vector2
        zoom::Float64
        yaw::Float64
        pitch::Float64
        target::Union{
            Ptr{Nothing}, 
            JulGame.TransformModule.Transform
            }
        windowPos::Vector2

        function Camera(size::Vector2, initialPosition::Vector3f, offset::Vector2f, target)
            this = new()
            
            this.id = JulGame.generate_uuid()
            this.name = "Camera"
            this.backgroundColor = (0,0,0, 255)
            this.size = size
            this.position = initialPosition
            this.offset = Math._Vector2{Float64}(offset.x, offset.y)
            this.target = target
            this.windowPos = Math._Vector2{Int32}(0, 0)
            this.zoom = 1.0
            this.yaw = 0.0
            this.pitch = 0.0

            return this
        end
    end

    """Pixels per world unit for 2D rendering (SCALE_UNITS × camera zoom)."""
    @inline function pixels_per_world_unit(camera::Union{Nothing, Camera})
        su = JulGame.scale_units()
        camera === nothing && return su
        return su * camera.zoom
    end

    """
        apply_zoom_to_center!(camera::Camera, new_zoom::Float64)

    Set `camera.zoom` to `new_zoom` and shift `camera.position` (x, y) so the world point
    that was at the viewport center stays there. `camera.offset` is not modified.
    """
    function apply_zoom_to_center!(camera::Camera, new_zoom::Float64)
        S_old = pixels_per_world_unit(camera)
        S_new = JulGame.scale_units() * new_zoom
        half_w = Float64(camera.size.x) / 2
        half_h = Float64(camera.size.y) / 2
        inv_delta = inv(S_old) - inv(S_new)
        dx = half_w * inv_delta
        dy = half_h * inv_delta
        camera.position = Math._Vector3{Float64}(
            camera.position.x + dx,
            camera.position.y + dy,
            camera.position.z,
        )
        camera.zoom = new_zoom
        return camera
    end

    function update(this::Camera, newPosition::Union{Nothing, Vector3f} = nothing)
        if !JulGame.IS_EDITOR && JulGame.WindowManagerModule.get_logical_size() != this.size
            JulGame.WindowManagerModule.set_logical_size(this.size.x, this.size.y)
            @debug "Logical size changed to $(this.size)"
        end

        SDL2.SDL_SetRenderDrawBlendMode(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, SDL2.SDL_BLENDMODE_BLEND)
        rgba = (r = Ref(UInt8(0)), g = Ref(UInt8(0)), b = Ref(UInt8(0)), a = Ref(UInt8(255)))
        SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r, rgba.g, rgba.b, rgba.a)
        SDL2.SDL_SetRenderDrawColor(Renderer, this.backgroundColor[1], this.backgroundColor[2], this.backgroundColor[3], this.backgroundColor[4]);
        SDL2.SDL_RenderFillRectF(Renderer, Ref(SDL2.SDL_FRect(this.windowPos.x, this.windowPos.y, this.size.x, this.size.y)))
        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[]);
        
        center_pixels = Math._Vector2{Float64}(Float64(this.size.x) / 2, Float64(this.size.y) / 2)
        center_world = center_pixels / pixels_per_world_unit(this)

        if this.target !== nothing && this.target !== C_NULL && newPosition === nothing
            targetPos::_Vector3{Float64} = this.target.position
            targetScale::_Vector3{Float64} = this.target.scale
            this.position = Math._Vector3{Float64}(targetPos.x - center_world.x + 0.5 * targetScale.x + this.offset.x,
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
