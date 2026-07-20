using StaticTools

# region Input 
# element_right / element_bottom are precomputed by the caller (x+width, y+height).
@inline function static_is_mouse_inside_element(
    mouse_x::Int32, mouse_y::Int32,
    element_x::Int32, element_y::Int32,
    element_right::Int32, element_bottom::Int32,
)::Int32
    x_ok::Int32 = Int32(mouse_x >= element_x) * Int32(mouse_x <= element_right)
    y_ok::Int32 = Int32(mouse_y >= element_y) * Int32(mouse_y <= element_bottom)
    return x_ok * y_ok
end

# SoA rects in layer order (front first). Returns 1-based index of first hit, or -1.
function static_ui_hit_test_batch(
    mouse_x::Int32, mouse_y::Int32,
    xs::Ptr{Int32}, ys::Ptr{Int32}, rights::Ptr{Int32}, bottoms::Ptr{Int32},
    n::Int32,
)::Int32
    i::Int32 = Int32(1)
    while i <= n
        ex::Int32 = unsafe_load(xs, Int(i))
        ey::Int32 = unsafe_load(ys, Int(i))
        er::Int32 = unsafe_load(rights, Int(i))
        eb::Int32 = unsafe_load(bottoms, Int(i))
        if static_is_mouse_inside_element(mouse_x, mouse_y, ex, ey, er, eb) != Int32(0)
            return i
        end
        i += Int32(1)
    end
    return Int32(-1)
end

# endregion Input 

# region Camera


# endregion Camera

# region Animator

function static_play_animation_once(animator::Ptr{Cvoid}, animation_index::Int32)
    if animator == C_NULL
        return
    end

    a = Ptr{AnimatorLayout}(animator)
    animations = a.animations
    if array_isempty(animations)
        return
    end

    n = array_length(animations)
    if animation_index < Int32(1) || Int64(animation_index) > n
        printf(c"Animation index out of bounds\n")
        return
    end

    data = array_data(Ptr{Cvoid}, animations)
    a.current_animation = unsafe_load(data, Int64(animation_index))
    a.play_once = true
    a.last_frame = Int64(1)
    return
end

function static_force_frame_update(animator::Ptr{Cvoid}, frame_index::Int32)
    if animator == C_NULL
        return
    end

    a = Ptr{AnimatorLayout}(animator)
    current_animation = a.current_animation
    if ptr_is_julia_nothing(current_animation)
        return
    end

    sprite = a.sprite
    if ptr_is_julia_nothing(sprite)
        return
    end

    anim = Ptr{AnimationLayout}(current_animation)

    # if !isempty(framePaths) → imagePath = framePaths[i]
    # Skipped for now: String assign needs write barrier + load_image.
    # frame_paths = anim.frame_paths
    # if !array_isempty(frame_paths)
    #     # TODO: sprite.imagePath = frame_paths[frame_index]
    # end

    frames = anim.frames
    if !array_isempty(frames)
        n = array_length(frames)
        if frame_index >= Int32(1) && Int64(frame_index) <= n
            data = array_data(Vector4i32, frames)
            crop = unsafe_load(data, Int64(frame_index))
            unsafe_store!(Ptr{Vector4i32}(Ptr{UInt8}(sprite) + SPRITE_CROP_OFF), crop)
            unsafe_store!(Ptr{UInt8}(Ptr{UInt8}(sprite) + SPRITE_CROP_TAG_OFF), UNION_TAG_VECTOR4)
        end
    end

    a.last_frame = Int64(frame_index)
    return
end
# endregion Animator
