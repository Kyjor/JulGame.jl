"""
# Generic 4D Vector structure

Two space dimensional vector <`x`,`y`,`z`,`t`>
This structure has read and rewrite the `x`, `y`, `z` and `t` components freedom.
"""
struct _Vector4{T}
    x::T
    y::T
    z::T
    t::T

    function _Vector4{T}(v::L) where {T,L}
      return (T <: Int32) ? new{T}(round(T,v),round(T,v),round(T,v),round(T,v)) :
      new{T}(convert(T,v),convert(T,v),convert(T,v),convert(T,v))
    end

    _Vector4{T}() where T = new{T}(0)

    function _Vector4{T}(x::L, y::P, z::Q, t::W) where {T,L,P,Q,W}
      return (T <: Int32) ? new{T}(round(T,x), round(T,y), round(T,z), round(T,t)) :
      new{T}(convert(T,x), convert(T,y), convert(T,z), convert(T,t))
    end

    # Operator overloading
    Base.:+(vec::_Vector4{T}, vec1::_Vector4{L}) where {T,L} = _Vector4{T}(vec.x + vec1.x, vec.y + vec1.y,
                                                                           vec1.z + vec.z, vec1.t + vec.t)
    Base.:+(vec::_Vector4{T}, a::Real) where T = _Vector4{T}(vec.x + a, vec.y + a, vec.z + a, vec.t + a)
    Base.:+(a::Real, vec::_Vector4{T}) where T = _Vector4{T}(vec.x + a, vec.y + a, vec.z + a, vec.t + a)
    Base.:+(vec::_Vector4{T}) where T = vec

    Base.:-(vec::_Vector4{T}, vec1::_Vector4{L}) where {T,L} = _Vector4{T}(vec.x - vec1.x, vec.y - vec1.y,
                                                                           vec.z - vec1.z, vec.t - vec1.t)
    Base.:-(vec::_Vector4{T}, a::Real) where T = _Vector4{T}(vec.x - a, vec.y - a, vec.z - a, vec.t - a)
    Base.:-(a::Real, vec::_Vector4{T}) where T = _Vector4{T}(a - vec.x, a - vec.y,a - vec.z, a - vec.t)
    Base.:-(vec::_Vector4{T}) where T = _Vector4{T}(-vec.x, -vec.y, -vec.z, -vec.t)

    Base.:*(vec::_Vector4{T}, vec1::_Vector4{L}) where {T,L} = _Vector4{T}(vec.x * vec1.x, vec.y * vec1.y,
                                                                           vec.z * vec1.z, vec.t * vec1.t)
    Base.:*(vec::_Vector4{T}, a::Real) where T = _Vector4{T}(vec.x * a, vec.y * a, vec.z * a, vec.t * a)
    Base.:*(a::Real, vec::_Vector4{T}) where T = _Vector4{T}(vec.x * a, vec.y * a, vec.z * a, vec.t * a)

    Base.:/(vec::_Vector4{T}, vec1::_Vector4{L}) where {T,L} = _Vector4{T}(vec.x / vec1.x, vec.y / vec1.y, 
                                                                           vec.z / vec1.z, vec.t / vec1.t)
    Base.:/(vec::_Vector4{T}, a::Real) where T = _Vector4{T}(vec.x / a, vec.y / a, vec.z / a, vec.t / a)
    Base.:/(a::Real, vec::_Vector4{T}) where T = _Vector4{T}(a / vec.x, a / vec.y, a / vec.z, a / vec.t)

    Base.:(==)(a::_Vector4{T}, b::_Vector4{L}) where {T,L} = (a.x == b.x && a.y == b.y && a.z == b.z && a.t == b.t)
end   

Vector4 = _Vector4{Int32}
Vector4f = _Vector4{Float64}
