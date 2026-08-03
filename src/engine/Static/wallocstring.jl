struct WallocString <: StaticTools.AbstractPointerString
    pointer::Ptr{UInt8}
    length::Int
end

@inline function WallocString(data::NTuple{N, UInt8}) where N
    s = WallocString(Ptr{UInt8}(wasm_malloc(UInt32(N))), N)
    s[:] = data
    return s
end

@inline function WallocString(s::AbstractString)
    N = length(s) + 1 # Add room for null-termination
    c = WallocString(undef, N)
    c[1:length(s)] = s
    return c
end
@inline WallocString(p::Ptr{UInt8}) = WallocString(p, strlen(p)+1)
@inline WallocString(argv::Ptr{Ptr{UInt8}}, n::Integer) = WallocString(unsafe_load(argv, n))

macro w_str(s)
    n = StaticTools._unsafe_unescape!(s)
    t = Expr(:tuple, codeunits(s)[1:n]..., 0x00)
    :(WallocString($t))
end

function str_ptr(str::WallocString)::Ptr{UInt8}
    len = UInt32(str.length)
    #allocate memory for the string
    ptr::Ptr{Cvoid} = wasm_malloc(len)
    #copy the string to the allocated memory
    for i = 1:len
        unsafe_store!(Ptr{UInt8}(ptr + i - 1), codeunit(str, i))
    end
    unsafe_store!(Ptr{UInt8}(ptr + len), 0x00)
    return ptr
end