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

# Copies a compile-time byte tuple with unrolled stores (no pointer to a c"..." StaticString).
@generated function copy_literal_bytes(dest::Ptr{UInt8}, dest_offset::UInt32, ::Val{bytes}) where {bytes}
    stores = Expr(:block)
    for (i, b) in enumerate(bytes)
        push!(stores.args, :(unsafe_store!(dest + dest_offset + $(UInt32(i - 1)), $(UInt8(b)))))
    end
    quote
        $stores
        return dest_offset + $(UInt32(length(bytes)))
    end
end

# "<base>/<infix><file>". infix is Val{(UInt8...)} so the prefix is immediates, not a C string pointer.
function malloc_joined_path(
    base_path::Ptr{UInt8},
    file_path::Ptr{UInt8},
    infix::Val{bytes},
)::Ptr{UInt8} where {bytes}
    if base_path == C_NULL || file_path == C_NULL
        return Ptr{UInt8}(C_NULL)
    end
    base_len::UInt32 = cstring_length(base_path)
    infix_len::UInt32 = UInt32(length(bytes))
    file_len::UInt32 = cstring_length(file_path)
    slash::UInt8 = 0x2f
    needs_slash::Bool = true
    if base_len > UInt32(0)
        last_base::UInt8 = unsafe_load(base_path + (base_len - UInt32(1)))
        if last_base == slash || last_base == 0x5c
            needs_slash = false
        end
    end
    slash_len::UInt32 = needs_slash ? UInt32(1) : UInt32(0)
    full_len::UInt32 = base_len + slash_len + infix_len + file_len + UInt32(1)
    full_path::Ptr{UInt8} = Ptr{UInt8}(wasm_malloc(full_len))
    write_at::UInt32 = copy_cstring_bytes(full_path, UInt32(0), base_path)
    if needs_slash
        unsafe_store!(full_path + write_at, slash)
        write_at += UInt32(1)
    end
    write_at = copy_literal_bytes(full_path, write_at, infix)
    write_at = copy_cstring_bytes(full_path, write_at, file_path)
    unsafe_store!(full_path + write_at, 0x00)
    return full_path
end

# "assets/images/" and "assets/sounds/" as immediates (no pointer(c"...")).
const ASSETS_IMAGES_INFIX = Val{(
    0x61, 0x73, 0x73, 0x65, 0x74, 0x73, 0x2f, 0x69, 0x6d, 0x61, 0x67, 0x65, 0x73, 0x2f,
)}()
const ASSETS_SOUNDS_INFIX = Val{(
    0x61, 0x73, 0x73, 0x65, 0x74, 0x73, 0x2f, 0x73, 0x6f, 0x75, 0x6e, 0x64, 0x73, 0x2f,
)}()

# Linked from jg_static_runtime.c (same dylib).
@inline function ptr_is_julia_nothing(p::Ptr{Cvoid})::Bool
    return ccall(:static_ptr_is_julia_nothing, Int32, (Ptr{Cvoid},), p) != Int32(0)
end
