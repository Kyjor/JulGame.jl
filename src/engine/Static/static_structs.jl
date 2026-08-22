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

struct Vector2f
    x::Float64
    y::Float64
end

struct Vector2i32
    x::Int32
    y::Int32
end

# InternalShape.color is Math.Vector3 = _Vector3{Int32}, not Vector3f.
struct Vector3i32
    x::Int32
    y::Int32
    z::Int32
end

struct Color4i64
    r::Int64
    g::Int64
    b::Int64
    a::Int64
end

struct Vector3f
    x::Float64
    y::Float64
    z::Float64
end

struct Vector4i32
    x::Int32
    y::Int32
    z::Int32
    t::Int32
end

struct RigidbodyLayout
    acceleration::Vector2f
    drag::Float64
    grounded::Bool
    mass::Float64
    offset::Vector2f
    parent::Ptr{Cvoid}
    useGravity::Bool
    velocity::Vector2f
end

# Field offsets must match fieldoffset(Transform). Stop at scale.
struct TransformLayout
    position::Vector3f
    scale::Vector3f
end

# Field offsets must match fieldoffset(Camera).
struct CameraLayout
    id::Ptr{Cvoid}
    name::Ptr{Cvoid}
    backgroundColor::Color4i64
    offset::Vector2f
    position::Vector3f
    size::Vector2i32
    zoom::Float64
    yaw::Float64
    pitch::Float64
    target::Ptr{Cvoid}
    windowPos::Vector2i32
end

# Field offsets must match fieldoffset(Entity). Stop at collider; later fields unused.
struct EntityLayout
    id::Ptr{Cvoid}
    name::Ptr{Cvoid}
    isActive::Bool
    persistentBetweenScenes::Bool
    transform::Ptr{TransformLayout}
    scripts::Ptr{Cvoid}
    parent::Ptr{Cvoid}
    animator::Ptr{Cvoid}
    collider::Ptr{Cvoid}
end

# Field offsets must match fieldoffset(InternalCollider). Stop at currentRests.
struct ColliderLayout
    collisionEvents::Ptr{Cvoid}
    currentCollisions::Ptr{Cvoid}
    currentRests::Ptr{Cvoid}
end

# Field offsets must match fieldoffset(InternalSoundSource). Stop at isPlaying.
struct SoundSourceLayout
    path::Ptr{Cvoid}
    isMusic::Bool
    channel::Int
    isPlaying::Bool
end

struct ShapeLayout
    position::Vector2f
    isFilled::Bool
    isWorldEntity::Bool
    layer::Int
    color::Vector3i32
    alpha::Int
    offset::Vector2f
    parent::Ptr{Cvoid}
    size::Vector2f
end

# Field offsets must match fieldoffset(InternalSprite). Stop at color (crop is a Union).
struct SpriteLayout
    imagePath::Ptr{Cvoid}
    layer::Int
    offset::Vector2f
    center::Vector2f
    rotation::Float64
    color::Color4i64
end