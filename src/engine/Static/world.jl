# Phase 1 — freestanding World (POD, no Julia GC).

const JG_WORLD_MAGIC = UInt32(0x4A475731) # "JGW1"
const JG_TRANSFORM_CAPACITY = Int32(64)

struct JGTransform
    x::Float64
    y::Float64
end

struct JGWorld
    magic::UInt32
    transform_capacity::Int32
    transform_length::Int32
    _pad::Int32
    transforms::Ptr{JGTransform}
end

function jg_world_load(world::Ptr{Cvoid})
    return unsafe_load(Ptr{JGWorld}(world))
end

# Returns world ptr, or C_NULL on failure.
function jg_world_create()
    wbytes::UInt64 = UInt64(sizeof(JGWorld))
    wptr::Ptr{Cvoid} = jg_malloc(wbytes)
    if wptr == C_NULL
        return Ptr{Cvoid}(C_NULL)
    end

    capacity::Int32 = JG_TRANSFORM_CAPACITY
    tbytes::UInt64 = UInt64(sizeof(JGTransform)) * UInt64(capacity)
    tptr::Ptr{Cvoid} = jg_malloc(tbytes)
    if tptr == C_NULL
        jg_free(wptr)
        return Ptr{Cvoid}(C_NULL)
    end

    tbase::Ptr{JGTransform} = Ptr{JGTransform}(tptr)
    i::Int32 = Int32(0)
    while i < capacity
        unsafe_store!(tbase + i, JGTransform(Float64(0), Float64(0)))
        i = i + Int32(1)
    end

    # Phase 1.2 smoke: one live transform at index 0.
    world::JGWorld = JGWorld(JG_WORLD_MAGIC, capacity, Int32(1), Int32(0), tbase)
    unsafe_store!(Ptr{JGWorld}(wptr), world)
    return wptr
end

# Returns 0 on success, 1 on bad ptr / magic.
function jg_world_destroy(world::Ptr{Cvoid})
    if world == C_NULL
        return Int32(1)
    end

    w::JGWorld = jg_world_load(world)
    if w.magic != JG_WORLD_MAGIC
        return Int32(1)
    end

    if w.transforms != Ptr{JGTransform}(C_NULL)
        jg_free(Ptr{Cvoid}(w.transforms))
    end
    jg_free(world)
    return Int32(0)
end

# x_bits/y_bits = Float64 bit patterns (reinterpret). Returns 0 ok, 1 error.
function jg_transform_set_pos(world::Ptr{Cvoid}, index::Int32, x_bits::Int64, y_bits::Int64)
    if world == C_NULL
        return Int32(1)
    end

    w::JGWorld = jg_world_load(world)
    if w.magic != JG_WORLD_MAGIC
        return Int32(1)
    end
    if index < Int32(0) || index >= w.transform_length
        return Int32(1)
    end

    x::Float64 = reinterpret(Float64, x_bits)
    y::Float64 = reinterpret(Float64, y_bits)
    unsafe_store!(w.transforms + index, JGTransform(x, y))
    return Int32(0)
end

# Writes Float64 bit patterns to out_x/out_y. Returns 0 ok, 1 error.
function jg_transform_get_pos(world::Ptr{Cvoid}, index::Int32, out_x::Ptr{Int64}, out_y::Ptr{Int64})
    if world == C_NULL || out_x == Ptr{Int64}(C_NULL) || out_y == Ptr{Int64}(C_NULL)
        return Int32(1)
    end

    w::JGWorld = jg_world_load(world)
    if w.magic != JG_WORLD_MAGIC
        return Int32(1)
    end
    if index < Int32(0) || index >= w.transform_length
        return Int32(1)
    end

    t::JGTransform = unsafe_load(w.transforms + index)
    unsafe_store!(out_x, reinterpret(Int64, t.x))
    unsafe_store!(out_y, reinterpret(Int64, t.y))
    return Int32(0)
end
