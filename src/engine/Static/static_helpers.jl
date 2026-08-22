# Ptr{T} field access + array / nothing helpers (sc-game style).

@generated function offsetof(::Type{X}, ::Val{field}) where {X, field}
    idx = findfirst(==(field), fieldnames(X))
    return fieldoffset(X, idx)
end

@inline function Base.getproperty(x::Ptr{T}, f::Symbol) where {T}
    return unsafe_load(Ptr{fieldtype(T, f)}(Ptr{UInt8}(x) + offsetof(T, Val(f))))
end

@inline function Base.setproperty!(x::Ptr{T}, f::Symbol, v) where {T}
    return unsafe_store!(Ptr{fieldtype(T, f)}(Ptr{UInt8}(x) + offsetof(T, Val(f))), convert(fieldtype(T, f), v))
end

@inline function array_length(arr::Ptr{Cvoid})::Int64
    return unsafe_load(Ptr{Int64}(Ptr{UInt8}(arr) + JL_ARRAY_LENGTH_OFF))
end

@inline function array_data(::Type{T}, arr::Ptr{Cvoid}) where {T}
    return unsafe_load(Ptr{Ptr{T}}(Ptr{UInt8}(arr) + JL_ARRAY_DATA_OFF))
end

@inline function array_isempty(arr::Ptr{Cvoid})::Bool
    return arr == C_NULL || array_length(arr) == Int64(0)
end

# In-place empty! (length = 0). Same Vector object; no alloc.
@inline function array_empty!(arr::Ptr{Cvoid})
    if array_isempty(arr)
        return
    end
    unsafe_store!(Ptr{Int64}(Ptr{UInt8}(arr) + JL_ARRAY_LENGTH_OFF), Int64(0))
    return
end

@inline function cstring_length(s::Ptr{UInt8})::UInt32
    n::UInt32 = UInt32(0)
    while unsafe_load(s + n) != 0x00
        n += UInt32(1)
    end
    return n
end

# Copies bytes until NUL. Returns dest offset after the last copied byte (NUL not written).
@inline function copy_cstring_bytes(dest::Ptr{UInt8}, dest_offset::UInt32, src::Ptr{UInt8})::UInt32
    i::UInt32 = UInt32(0)
    while true
        b::UInt8 = unsafe_load(src + i)
        if b == 0x00
            return dest_offset + i
        end
        unsafe_store!(dest + dest_offset + i, b)
        i += UInt32(1)
    end
end

# Linked from jg_static_runtime.c (same dylib).
@inline function ptr_is_julia_nothing(p::Ptr{Cvoid})::Bool
    return ccall(:static_ptr_is_julia_nothing, Int32, (Ptr{Cvoid},), p) != Int32(0)
end
