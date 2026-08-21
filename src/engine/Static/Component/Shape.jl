function static_draw_shape(
    shape::Ptr{Cvoid},
    renderer::Ptr{Cvoid},
    camera::Ptr{Cvoid},
    scale_units_bits::Int64,
)
    if shape == C_NULL || renderer == C_NULL
        return
    end

    this = Ptr{ShapeLayout}(shape)
    parent_raw::Ptr{Cvoid} = this.parent
    if ptr_is_julia_nothing(parent_raw)
        return
    end
    parent_ptr = Ptr{EntityLayout}(parent_raw)
    transform_ptr::Ptr{TransformLayout} = parent_ptr.transform
    parent_scale::Vector3f = transform_ptr.scale
    shape_offset::Vector2f = this.offset

    scale_units::Float64 = reinterpret(Float64, scale_units_bits)
    S::Float64 = scale_units
    camera_diff_x::Float64 = Float64(0.0)
    camera_diff_y::Float64 = Float64(0.0)
    is_world::Bool = this.isWorldEntity
    if is_world
        if camera != C_NULL
            if !ptr_is_julia_nothing(camera)
                cam = Ptr{CameraLayout}(camera)
                S = scale_units * cam.zoom
                cam_pos::Vector3f = cam.position
                cam_off::Vector2f = cam.offset
                camera_diff_x = (cam_pos.x + cam_off.x) * S
                camera_diff_y = (cam_pos.y + cam_off.y) * S
            end
        end
    end

    pos_x::Float64 = Float64(0.0)
    pos_y::Float64 = Float64(0.0)
    if is_world
        parent_position::Vector3f = transform_ptr.position
        pos_x = parent_position.x
        pos_y = parent_position.y
    else
        local_position::Vector2f = this.position
        pos_x = local_position.x
        pos_y = local_position.y
    end

    half::Float64 = Float64(0.5)
    x_f::Float64 = (pos_x + shape_offset.x) * S - camera_diff_x - (parent_scale.x * S - S) * half
    y_f::Float64 = (pos_y + shape_offset.y) * S - camera_diff_y - (parent_scale.y * S - S) * half
    w_f::Float64 = parent_scale.x * S
    h_f::Float64 = parent_scale.y * S

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

    color = this.color
    llvm_SDL_SetRenderDrawColor(
        renderer,
        unsafe_trunc(UInt8, color.x),
        unsafe_trunc(UInt8, color.y),
        unsafe_trunc(UInt8, color.z),
        unsafe_trunc(UInt8, this.alpha),
    )

    fill_rect::Ptr{Cvoid} = wasm_malloc(UInt32(16))
    unsafe_store!(
        Ptr{SDL_FRect}(fill_rect),
        SDL_FRect(Float32(x_f), Float32(y_f), Float32(w_f), Float32(h_f)),
    )
    if this.isFilled
        llvm_SDL_RenderFillRectF(renderer, fill_rect)
    else
        llvm_SDL_RenderDrawRectF(renderer, fill_rect)
    end
    wasm_free(fill_rect)

    llvm_SDL_SetRenderDrawColor(renderer, saved_r, saved_g, saved_b, saved_a)
    return
end
