import Base: convert

struct Vector4
    x::Int64
    y::Int64
    w::Int64
    h::Int64
    #default constructor
    Vector4() = new(0, 0, 0, 0)
    Vector4(num::Number) = new(convert(Int64,num), convert(Int64,num), convert(Int64,num), convert(Int64,num))
    Vector4(x::Int64, y::Int64) = new(x, y, x, y)
    Vector4(x::Int64, y::Int64, w::Int64, h::Int64) = new(x,y,w,h)
    Vector4(x::Number, y::Number, w::Number, h::Number) = new(convert(Int64,x),convert(Int64,y),convert(Int64,w),convert(Int64,h))
end   
