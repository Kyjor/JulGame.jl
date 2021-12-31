__precompile__()
struct Vector2f
    x::Float64
    y::Float64
    #default constructor
    Vector2f() = new(0.0, 0.0)
    
    Vector2f(x::Float64, y::Float64) = new(x,y)

    #convert if int
    Vector2f(x::Int64, y::Int64) = new(convert(Float64,x),convert(Float64,y));
    Vector2f(x::Float64, y::Int64) = new(x,convert(Float64,y));
    Vector2f(x::Int64, y::Float64) = new(convert(Float64,x),y);
    
    function print()
        println(x + ", " + y)
    end
end   
