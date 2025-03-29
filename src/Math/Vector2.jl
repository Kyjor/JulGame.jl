"""
# Generic 2D Vector structure

Two space dimensional vector <`x`,`y`>. 
This structure has read and rewrite the `x` and `y` components freedom.
"""
struct _Vector2{T}
    x::T
    y::T

    function _Vector2{T}(value::L) where {T,L}
        if T <: Int32
            return new{T}(Math.TypeConversions.safe_int32_convert(value), 
                         Math.TypeConversions.safe_int32_convert(value))
        end
        return new{T}(convert(T,value), convert(T,value))
    end

    _Vector2{T}() where T = new{T}(convert(T,0), convert(T,0))

    function _Vector2{T}(x::L, y::P) where {T,L,P}
        if T <: Int32
            return new{T}(Math.TypeConversions.safe_int32_convert(x),
                         Math.TypeConversions.safe_int32_convert(y))
        end
        return new{T}(convert(T,x), convert(T,y))
    end

    # Operator overloading
    # +
    Base.:+(vec_a::_Vector2{T}, vec_b::_Vector2{L}) where {T,L} = _Vector2{T}(vec_a.x + vec_b.x, vec_a.y + vec_b.y)
    Base.:+(vec_a::_Vector2{T}, b::L) where {T,L} = _Vector2{T}(vec_a.x + b, vec_a.y + b)
    Base.:+(a::L, vec_b::_Vector2{T}) where {T,L} = _Vector2{T}(vec_b.x + a, vec_b.y + a)
    Base.:+(vec_a::_Vector2{T}) where T = vec_a

    Base.:-(vec_a::_Vector2{T}, vec_b::_Vector2{L}) where {T,L} = _Vector2{T}(vec_a.x - vec_b.x, vec_a.y - vec_b.y)
    Base.:-(vec_a::_Vector2{T}, b::Real) where {T} = _Vector2{T}(vec_a.x - b, vec_a.y - b)
    Base.:-(a::Real, vec_b::_Vector2{T}) where {T} = _Vector2{T}(a - vec_b.x,a - vec_b.y)
    Base.:-(vec_a::_Vector2{T}) where T = _Vector2{T}(-vec_a.x, -vec_a.y)

    Base.:*(vec_a::_Vector2{T}, vec_b::_Vector2{L}) where {T,L} = _Vector2{T}(vec_a.x * vec_b.x, vec_a.y * vec_b.y)
    Base.:*(vec::_Vector2{T}, scalar::Real) where T = _Vector2{T}(vec.x * scalar, vec.y * scalar)
    Base.:*(scalar::Real, vec::_Vector2{T}) where T = vec * scalar

    Base.:/(vec_a::_Vector2{T}, vec_b::_Vector2{L}) where {T,L} = _Vector2{T}(vec_a.x / vec_b.x, vec_a.y / vec_b.y)
    Base.:/(vec::_Vector2{T}, scalar::Real) where T = _Vector2{T}(vec.x / scalar, vec.y / scalar)
    Base.:/(scalar::Real, vec::_Vector2{T}) where T = _Vector2{T}(scalar / vec.x, scalar / vec.y)

    Base.:(==)(a::_Vector2{T}, b::_Vector2{L}) where {T,L} = (a.x == b.x && a.y == b.y)
end

Vector2 = _Vector2{Int32}
Vector2f = _Vector2{Float64}
