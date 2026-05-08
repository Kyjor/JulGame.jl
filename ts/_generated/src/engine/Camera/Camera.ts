
    // using ..JulGame
    // using .Math

    

    class Camera {
        id: string
        name: string
		backgroundColor: [number, number, number, number]
        offset: Vector2f
        position: Vector3f
        size: Vector2
        zoom: number
        yaw: number
        pitch: number
        target: null | Transform
        windowPos: Vector2

        constructor(size: Vector2,  initialPosition: Vector3f,  offset: Vector2f,  target) {
            
            
            this.id = JulGame.generate_uuid()
            this.name = "Camera"
            this.backgroundColor = [0,0,0, 255]
            this.size = size
            this.position = initialPosition
            this.offset = {x: offset.x, y: offset.y}
            this.target = target
            this.windowPos = Vector2(0,0)
            this.zoom = 1.0
            this.yaw = 0.0
            this.pitch = 0.0

        }
    }

    /*Pixels per world unit for 2D rendering (SCALE_UNITS × camera zoom).*/
    function pixels_per_world_unit(camera: Nothing | Camera) {
        camera === nothing && return JulGame.SCALE_UNITS
        return JulGame.SCALE_UNITS * camera.zoom
    }

    /*
        apply_zoom_to_center(camera::Camera, new_zoom: number)

    Set `camera.zoom` to `new_zoom` and shift `camera.position` (x, y) so the world point
    that was at the viewport center stays there. `camera.offset` is not modified.
    */
    function apply_zoom_to_center(camera: Camera,  new_zoom: number) {
        let S_old = pixels_per_world_unit(camera)
        let S_new = JulGame.SCALE_UNITS * new_zoom
        let half_w = Float64(camera.size.x) / 2
        let half_h = Float64(camera.size.y) / 2
        let inv_delta = inv(S_old) - inv(S_new)
        let dx = half_w * inv_delta
        let dy = half_h * inv_delta
        camera.position = Vector3f(
            camera.position.x + dx,
            camera.position.y + dy,
            camera.position.z,
        )
        camera.zoom = new_zoom
        return camera
    }

    function update(this: Camera,  newPosition: Nothing | Vector3f = nothing) {
        if (!JulGame.IS_EDITOR && JulGame.WindowManagerModule.get_logical_size() != this.size) {
            JulGame.WindowManagerModule.set_logical_size(this.size.x, this.size.y)
            console.debug("Logical size changed to $(this.size)")
        }

        SDL2.SDL_SetRenderDrawBlendMode(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, SDL2.SDL_BLENDMODE_BLEND)
        let rgba = (r = Ref(UInt8(0)), g = Ref(UInt8(0)), b = Ref(UInt8(0)), a = Ref(UInt8(255)))
        SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r, rgba.g, rgba.b, rgba.a)
        SDL2.SDL_SetRenderDrawColor(Renderer, this.backgroundColor[1], this.backgroundColor[2], this.backgroundColor[3], this.backgroundColor[4]);
        SDL2.SDL_RenderFillRectF(Renderer, Ref(SDL2.SDL_FRect(this.windowPos.x, this.windowPos.y, this.size.x, this.size.y)))
        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[]);
        
        let center_pixels = {x: this.size.x / 2, y: this.size.y / 2}
        let center_world = center_pixels / pixels_per_world_unit(this)

        if (this.target !== nothing && this.target !== null && newPosition === nothing) {
            targetPos::Vector3f = this.target.position
            targetScale::Vector2f = this.target.scale
            this.position = Vector3f(targetPos.x - center_world.x + 0.5 * targetScale.x + this.offset.x,
                                     targetPos.y - center_world.y + 0.5 * targetScale.y + this.offset.y, 
                                     targetPos.z)
            return
        }

        if (newPosition !== nothing) {
            this.position = newPosition
        }
    }

    // making set property observable
    function Base.setproperty(this: Camera,  s: Symbol,  x) {
        @debug("setting camera property $(s) to: $(x)")
        try
            setfield(this, s, x)
        catch e
            println(e)
        }
    }
