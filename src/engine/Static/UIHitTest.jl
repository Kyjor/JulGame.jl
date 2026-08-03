# Julia-side UI hit testing: reference implementation, HitTestBuffer, and optional native calls.
module UIHitTestModule

using ..JGStaticModule

const LIB_PATH = JGStaticModule.LIB_PATH
const LIB_AVAILABLE = JGStaticModule.LIB_AVAILABLE

# Batch path: one ccall per mouse event (set JULGAME_STATIC_UI_HIT_BATCH=1).
const USE_STATIC_UI_HIT_BATCH =
    get(ENV, "JULGAME_STATIC_UI_HIT_BATCH", "0") == "1" && LIB_AVAILABLE

# Scalar path: per-element ccall for A/B debugging (set JULGAME_STATIC_UI_HIT_SCALAR_DEBUG=1).
const USE_STATIC_UI_HIT_SCALAR_DEBUG =
    get(ENV, "JULGAME_STATIC_UI_HIT_SCALAR_DEBUG", "0") == "1" && LIB_AVAILABLE

@info "USE_STATIC_UI_HIT_BATCH: $USE_STATIC_UI_HIT_BATCH"

function use_static_ui_hit_batch()::Bool
    USE_STATIC_UI_HIT_BATCH
end

function use_static_ui_hit_scalar_debug()::Bool
    USE_STATIC_UI_HIT_SCALAR_DEBUG
end

"""Julia reference — production default when batch/static flags are off."""
function is_mouse_inside_element_julia(
    mouse_x::Real, mouse_y::Real,
    element_x::Real, element_y::Real,
    element_right::Real, element_bottom::Real,
)::Bool
    mouse_x < element_x && return false
    mouse_x > element_right && return false
    mouse_y < element_y && return false
    mouse_y > element_bottom && return false
    return true
end

function is_mouse_inside_element_scalar_static(
    mouse_x::Real, mouse_y::Real,
    element_x::Real, element_y::Real,
    element_right::Real, element_bottom::Real,
)::Bool
    hit = ccall(
        (:static_is_mouse_inside_element, LIB_PATH),
        Int32,
        (Int32, Int32, Int32, Int32, Int32, Int32),
        Int32(round(mouse_x)), Int32(round(mouse_y)),
        Int32(round(element_x)), Int32(round(element_y)),
        Int32(round(element_right)), Int32(round(element_bottom)),
    )
    return hit != 0
end

mutable struct HitTestBuffer
    xs::Vector{Int32}
    ys::Vector{Int32}
    rights::Vector{Int32}
    bottoms::Vector{Int32}
    elements::Vector{Any}
    count::Int

    function HitTestBuffer(capacity::Int = 64)
        new(
            Vector{Int32}(undef, capacity),
            Vector{Int32}(undef, capacity),
            Vector{Int32}(undef, capacity),
            Vector{Int32}(undef, capacity),
            Vector{Any}(undef, capacity),
            0,
        )
    end
end

function clear!(buf::HitTestBuffer)
    buf.count = 0
    return buf
end

function ensure_capacity!(buf::HitTestBuffer, needed::Int)
    if length(buf.xs) >= needed
        return buf
    end
    new_cap = max(needed, length(buf.xs) * 2)
    resize!(buf.xs, new_cap)
    resize!(buf.ys, new_cap)
    resize!(buf.rights, new_cap)
    resize!(buf.bottoms, new_cap)
    resize!(buf.elements, new_cap)
    return buf
end

function push_rect!(buf::HitTestBuffer, element::Any, x::Real, y::Real, right::Real, bottom::Real)
    buf.count += 1
    ensure_capacity!(buf, buf.count)
    buf.xs[buf.count] = Int32(round(x))
    buf.ys[buf.count] = Int32(round(y))
    buf.rights[buf.count] = Int32(round(right))
    buf.bottoms[buf.count] = Int32(round(bottom))
    buf.elements[buf.count] = element
    return buf
end

function run_static_hit_test_batch!(buf::HitTestBuffer, mouse_x::Real, mouse_y::Real)::Int
    n = buf.count
    n == 0 && return -1
    idx = ccall(
        (:static_ui_hit_test_batch, LIB_PATH),
        Int32,
        (Int32, Int32, Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32),
        Int32(round(mouse_x)), Int32(round(mouse_y)),
        pointer(buf.xs), pointer(buf.ys), pointer(buf.rights), pointer(buf.bottoms),
        Int32(n),
    )
    return Int(idx)
end

function first_hit_index_julia(buf::HitTestBuffer, mouse_x::Real, mouse_y::Real)::Int
    for i in 1:buf.count
        if is_mouse_inside_element_julia(
            mouse_x, mouse_y,
            buf.xs[i], buf.ys[i], buf.rights[i], buf.bottoms[i],
        )
            return i
        end
    end
    return -1
end

export HitTestBuffer,
       clear!,
       ensure_capacity!,
       push_rect!,
       run_static_hit_test_batch!,
       first_hit_index_julia,
       is_mouse_inside_element_julia,
       is_mouse_inside_element_scalar_static,
       use_static_ui_hit_batch,
       use_static_ui_hit_scalar_debug

end
