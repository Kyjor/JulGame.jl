function static_update_camera(camera::Ptr{Cvoid}, renderer::Ptr{Cvoid}, scale_units_bits::Int64)
    if camera == C_NULL
        return
    end

    cam = Ptr{CameraLayout}(camera)
    camera_size = cam.size
    if renderer != C_NULL
        saved_color::Ptr{UInt8} = Ptr{UInt8}(wasm_malloc(UInt32(4)))
        llvm_SDL_GetRenderDrawColor(
            renderer,
            saved_color,
            saved_color + 1,
            saved_color + 2,
            saved_color + 3,
        )
        saved_r::UInt8 = unsafe_load(saved_color)
        saved_g::UInt8 = unsafe_load(saved_color + 1)
        saved_b::UInt8 = unsafe_load(saved_color + 2)
        saved_a::UInt8 = unsafe_load(saved_color + 3)
        wasm_free(Ptr{Cvoid}(saved_color))
        background_color = cam.backgroundColor
        window_pos = cam.windowPos
        llvm_SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND)
        llvm_SDL_SetRenderDrawColor(
            renderer,
            unsafe_trunc(UInt8, background_color.r),
            unsafe_trunc(UInt8, background_color.g),
            unsafe_trunc(UInt8, background_color.b),
            unsafe_trunc(UInt8, background_color.a),
        )
        fill_rect::Ptr{Cvoid} = wasm_malloc(UInt32(16))
        unsafe_store!(
            Ptr{SDL_FRect}(fill_rect),
            SDL_FRect(
                Float32(window_pos.x),
                Float32(window_pos.y),
                Float32(camera_size.x),
                Float32(camera_size.y),
            ),
        )
        llvm_SDL_RenderFillRectF(renderer, fill_rect)
        wasm_free(fill_rect)
        llvm_SDL_SetRenderDrawColor(renderer, saved_r, saved_g, saved_b, saved_a)
    end

    target::Ptr{Cvoid} = cam.target
    if ptr_is_julia_nothing(target)
        return
    end

    target_transform = Ptr{TransformLayout}(target)
    target_position = target_transform.position
    target_scale = target_transform.scale
    camera_offset = cam.offset
    scale_units::Float64 = reinterpret(Float64, scale_units_bits)
    pixels_per_world_unit::Float64 = scale_units * cam.zoom
    half::Float64 = Float64(0.5)
    center_world_x::Float64 = Float64(camera_size.x) * half
    center_world_y::Float64 = Float64(camera_size.y) * half
    if pixels_per_world_unit != Float64(0.0)
        center_world_x = center_world_x / pixels_per_world_unit
        center_world_y = center_world_y / pixels_per_world_unit
    end
    cam.position = Vector3f(
        target_position.x - center_world_x + half * target_scale.x + camera_offset.x,
        target_position.y - center_world_y + half * target_scale.y + camera_offset.y,
        target_position.z,
    )
    return
end
