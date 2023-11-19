struct Vector2
    x::Int64
    y::Int64
    #default constructor
    Vector2() = new(0, 0)
    Vector2(value::Number) = new(convert(Int64, round(value)), convert(Int64, round(value)))

    Vector2(x::Int64, y::Int64) = new(x,y)
    Vector2(x::Int32, y::Int32) = new(convert(Int64, x), convert(Int64, y))

    #convert if float
    Vector2(x::Float64, y::Float64) = new(convert(Int64,round(x)),convert(Int64,round(y)));
    Vector2(x::Int64, y::Float64) = new(x,convert(Int64,round(y)));
    Vector2(x::Float64, y::Int64) = new(convert(Int64,round(x)),y);

    #operators 
    function Base.:+(vec::Vector2, vec1::Vector2)
        return Vector2(vec.x + vec1.x, vec.y + vec1.y)
    end

    function Base.:-(vec::Vector2, vec1::Vector2)
        return Vector2(vec.x - vec1.x, vec.y - vec1.y)
    end

    function Base.:*(vec::Vector2, vec1::Vector2)
        return Vector2(vec.x * vec1.x, vec.y * vec1.y)
    end

    function Base.:*(vec::Vector2, int::Int64)
        return Vector2(vec.x * int, vec.y * int)
    end
    
    function Base.:*(vec::Vector2, float::Float64)
        return Vector2(vec.x * float, vec.y * float)
    end
    
    function Base.:*(float::Float64, vec::Vector2)
        return Vector2(vec.x * float, vec.y * float)
    end

    function Base.:/(vec::Vector2, float::Float64)
        return Vector2(vec.x / float, vec.y / float)
    end
end   
