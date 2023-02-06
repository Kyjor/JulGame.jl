__precompile__()
struct Vector2f
    x::Float64
    y::Float64
    #default constructor
    Vector2f() = new(0.0, 0.0)
    
    Vector2f(x::Float64, y::Float64) = new(x,y)

    #convert if int
    Vector2f(x::Int64, y::Int64) = new(convert(Float64,round(x)),convert(Float64,round(y)));
    Vector2f(x::Float64, y::Int64) = new(x,convert(Float64,round(y)));
    Vector2f(x::Int64, y::Float64) = new(convert(Float64,round(x)),y);
    

    #operators 
    function Base.:*(vec::Vector2f, int::Int64)
        return Vector2f(vec.x * int, vec.y * int)
    end
    
    function Base.:*(vec::Vector2f, float::Float64)
        return Vector2f(vec.x * float, vec.y * float)
    end
    
    function print()
        println(x + ", " + y)
    end
end   
