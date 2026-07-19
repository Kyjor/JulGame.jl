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
    printf(c"test\n")
    return Cvoid()
end

function static_force_frame_update(animator::Ptr{Cvoid}, frame_index::Int32)
    printf(c"test\n")
end
# endregion Animator
