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
        return (T <: Int) ? new{T}(round(T,v),round(T,v),round(T,v)) :
            new{T}(convert(T,v),convert(T,v),convert(T,v))
    end

    _Vector3{T}() where T = new{T}(0)

    function _Vector3{T}(x::L, y::P, z::Q) where {T,L,P,Q}
        return (T <: Int) ? new{T}(round(T,x), round(T,y), round(T,z)) :
            new{T}(convert(T,x), convert(T,y), convert(T,z))
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
end   

Vector3 = _Vector3{Int}
Vector3f = _Vector3{Float64}
