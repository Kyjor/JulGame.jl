import Base: convert

struct Vector4
    x::Integer
    y::Integer
    w::Integer
    h::Integer
    #default constructor
    Vector4() = new(0, 0, 0, 0)
    Vector4(num::Number) = new(convert(Integer,num), convert(Integer,num), convert(Integer,num), convert(Integer,num))
    Vector4(x::Integer, y::Integer) = new(x, y, x, y)
    Vector4(x::Integer, y::Integer, w::Integer, h::Integer) = new(x,y,w,h)
    Vector4(x::Number, y::Number, w::Number, h::Number) = new(convert(Integer,x),convert(Integer,y),convert(Integer,w),convert(Integer,h))
end   
