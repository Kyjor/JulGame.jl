export {}

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
        target: null | ITransform
        windowPos: Vector2

        constructor(size: Vector2,  initialPosition: Vector3f,  offset: Vector2f,  target) {
            
            
            this.id = (globalThis as any).JulGame.generate_uuid()
            this.name = "Camera"
            this.backgroundColor = [0,0,0, 255]
            this.size = size
            this.position = initialPosition
            this.offset = {x: offset.x, y: offset.y}
            this.target = target
            this.windowPos = {x: 0, y: 0}
            this.zoom = 1.0
            this.yaw = 0.0
            this.pitch = 0.0

        }
    }

    /*Pixels per world unit for 2D rendering (SCALE_UNITS × camera zoom).*/
    function pixels_per_world_unit(camera: null | Camera) {
        if (camera === null) { return (globalThis as any).JulGame.SCALE_UNITS }
        return (globalThis as any).JulGame.SCALE_UNITS * camera.zoom
    }

    /*
        apply_zoom_to_center(camera, new_zoom: number)

    Set `camera.zoom` to `new_zoom` and shift `camera.position` (x, y) so the world point
    that was at the viewport center stays there. `camera.offset` is not modified.
    */
    function apply_zoom_to_center(camera: Camera,  new_zoom: number) {
        let S_old = pixels_per_world_unit(camera)
        let S_new = (globalThis as any).JulGame.SCALE_UNITS * new_zoom
        let half_w = Number(camera.size.x) / 2
        let half_h = Number(camera.size.y) / 2
        let inv_delta = (1 / (S_old)) - (1 / (S_new))
        let dx = half_w * inv_delta
        let dy = half_h * inv_delta
        camera.position = {x: camera.position.x + dx, y: camera.position.y + dy, z: camera.position.z,
        }
        camera.zoom = new_zoom
        return camera
    }

    function update(this: Camera,  newPosition: null | Vector3f = null) {
        if ((globalThis as any).JulGame.IS_EDITOR && (globalThis as any).JulGame.WindowManagerModule.get_logical_size() != this.size) {
            (globalThis as any).JulGame.WindowManagerModule.set_logical_size(this.size.x, this.size.y)
            console.debug("Logical size changed to $(this.size)")
        }
(globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawBlendMode_BLEND()
        (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor(this.backgroundColor[0], this.backgroundColor[1], this.backgroundColor[2], this.backgroundColor[3]);
        (globalThis as any).JulGameSdl.glue_SDL_RenderFillRectF(Ref((globalThis as any).JulGameSdl.glue_SDL_FRect(this.windowPos.x, this.windowPos.y, this.size.x, this.size.y)))
        (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor((globalThis as any).JulGame.Renderer, rgba.r, rgba.g, rgba.b, rgba.a);
        
        let center_pixels = {x: this.size.x / 2, y: this.size.y / 2}
        let center_world = {x: center_pixels.x / pixels_per_world_unit(this), y: center_pixels.y / pixels_per_world_unit(this)}

        if (this.target !== null && this.target !== null && newPosition === null) {
            let targetPos = this.target.position
            let targetScale = this.target.scale
            this.position = {x: targetPos.x - center_world.x + 0.5 * targetScale.x + this.offset.x, y: targetPos.y - center_world.y + 0.5 * targetScale.y + this.offset.y, z: targetPos.z}
            return
        }

        if (newPosition !== null) {
            this.position = newPosition
        }
    }

    // making set property observable

