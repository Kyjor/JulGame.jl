# Layout mirrors of JulGame types (Julia 1.11).
# Field offsets must match fieldoffset(InternalAnimator / Animation / ...).

struct AnimatorLayout
    animations::Ptr{Cvoid}
    current_animation::Ptr{Cvoid}
    last_frame::Int64
    last_update::UInt64
    parent::Ptr{Cvoid}
    play_once::Bool
    sprite::Ptr{Cvoid}
end

struct AnimationLayout
    animated_fps::Int32
    frames::Ptr{Cvoid}
    frame_paths::Ptr{Cvoid}
end

struct Vector4i32
    x::Int32
    y::Int32
    z::Int32
    t::Int32
end
