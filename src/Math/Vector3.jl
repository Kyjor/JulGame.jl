"""
# Generic 3D Vector structure

Two space dimensional vector <`x`,`y`,`z`>
This structure has read and rewrite the `x`, `y` and `z` components freedom.
"""
struct _Vector3{T}
    x::T
    y::T
    z::T

    function _Vector3{T}(v::L) where {T,L}
        if T <: Int32
            return new{T}(Math.TypeConversions.safe_int32_convert(v),
                         Math.TypeConversions.safe_int32_convert(v),
                         Math.TypeConversions.safe_int32_convert(v))
        end
        return new{T}(convert(T,v), convert(T,v), convert(T,v))
    end

    _Vector3{T}() where T = new{T}(0)

    function _Vector3{T}(x::L, y::P, z::Q) where {T,L,P,Q}
        if T <: Int32
            return new{T}(Math.TypeConversions.safe_int32_convert(x),
                         Math.TypeConversions.safe_int32_convert(y),
                         Math.TypeConversions.safe_int32_convert(z))
        end
        return new{T}(convert(T,x), convert(T,y), convert(T,z))
    end

    function _Vector3{T}(vec2::_Vector2{L}) where {T,L}
        if T <: Int32
            return new{T}(Math.TypeConversions.safe_int32_convert(vec2.x),
                         Math.TypeConversions.safe_int32_convert(vec2.y),
                         0)
        end
        return new{T}(convert(T,vec2.x), convert(T,vec2.y), 0)
    end

    # Operator overloading
    Base.:+(vec::_Vector3{T}, vec1::_Vector3{L}) where {T,L} = _Vector3{T}(vec.x + vec1.x, vec.y + vec1.y,
                                                                           vec1.z + vec.z)
    Base.:+(vec::_Vector3{T}, a::Real) where T = _Vector3{T}(vec.x + a, vec.y + a, vec.z + a)
    Base.:+(a::Real, vec::_Vector3{T}) where T = _Vector3{T}(vec.x + a, vec.y + a, vec.z + a)
    Base.:+(vec::_Vector3{T}) where T = vec

    Base.:-(vec::_Vector3{T}, vec1::_Vector3{L}) where {T,L} = _Vector3{T}(vec.x - vec1.x, vec.y - vec1.y,
                                                                           vec.z - vec1.z)
    Base.:-(vec::_Vector3{T}, a::Real) where T = _Vector3{T}(vec.x - a, vec.y - a, vec.z - a)
    Base.:-(a::Real, vec::_Vector3{T}) where T = _Vector3{T}(a - vec.x, a - vec.y,a - vec.z)
    Base.:-(vec::_Vector3{T}) where T = _Vector3{T}(-vec.x, -vec.y, -vec.z)

    Base.:*(vec::_Vector3{T}, vec1::_Vector3{L}) where {T,L} = _Vector3{T}(vec.x * vec1.x, vec.y * vec1.y,
                                                                           vec.z * vec1.z)
    Base.:*(vec::_Vector3{T}, a::Real) where T = _Vector3{T}(vec.x * a, vec.y * a, vec.z * a)
    Base.:*(a::Real, vec::_Vector3{T}) where T = _Vector3{T}(vec.x * a, vec.y * a, vec.z * a)

    Base.:/(vec::_Vector3{T}, vec1::_Vector3{L}) where {T,L} = _Vector3{T}(vec.x / vec1.x, vec.y / vec1.y, 
                                                                           vec.z / vec1.z)
    Base.:/(vec::_Vector3{T}, a::Real) where T = _Vector3{T}(vec.x / a, vec.y / a, vec.z / a)
    Base.:/(a::Real, vec::_Vector3{T}) where T = _Vector3{T}(a / vec.x, a / vec.y, a / vec.z)

    Base.:(==)(a::_Vector3{T}, b::_Vector3{L}) where {T,L} = (a.x == b.x && a.y == b.y && a.z == b.z)
    Base.:(==)(a::_Vector3{T}, b::_Vector2{L}) where {T,L} = (a.x == b.x && a.y == b.y && a.z == 0)
    Base.:(==)(a::_Vector2{L}, b::_Vector3{T}) where {T,L} = (a.x == b.x && a.y == b.y && b.z == 0)
end   

Vector3 = _Vector3{Int32}
Vector3f = _Vector3{Float64}
