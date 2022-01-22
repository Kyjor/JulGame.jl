__precompile__()
struct Vector2i
    x::Int64
    y::Int64
    #default constructor
    Vector2i() = new(0.0, 0.0)
    
    Vector2i(x::Int64, y::Int64) = new(x,y)

    #convert if int
    Vector2i(x::Float64, y::Float64) = new(convert(Int64,x),convert(Int64,y));
    Vector2i(x::Int64, y::Float64) = new(x,convert(Int64,y));
    Vector2i(x::Float64, y::Int64) = new(convert(Int64,x),y);
    
    function print()
        println(x + ", " + y)
    end
end   
