struct Vector4
    x::Int64
    y::Int64
    w::Int64
    h::Int64
    #default constructor
    Vector4() = new(0, 0, 0, 0)
    Vector4(x::Int64, y::Int64) = new(x, y, x, y)
    Vector4(x::Int64, y::Int64, w::Int64, h::Int64) = new(x,y,w,h)
end   
