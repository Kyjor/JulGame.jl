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

# Linked from jg_static_runtime.c (same dylib).
@inline function ptr_is_julia_nothing(p::Ptr{Cvoid})::Bool
    return ccall(:static_ptr_is_julia_nothing, Int32, (Ptr{Cvoid},), p) != Int32(0)
end
