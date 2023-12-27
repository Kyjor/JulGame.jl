struct Vector2
    x::Integer
    y::Integer
    #default constructor
    Vector2() = new(0, 0)
    Vector2(value::Number) = new(convert(Integer, round(value)), convert(Integer, round(value)))

    Vector2(x::Integer, y::Integer) = new(x,y)

    #convert if float
    Vector2(x::Float64, y::Float64) = new(convert(Integer,round(x)),convert(Integer,round(y)));
    Vector2(x::Integer, y::Float64) = new(x,convert(Integer,round(y)));
    Vector2(x::Float64, y::Integer) = new(convert(Integer,round(x)),y);

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

    function Base.:*(vec::Vector2, int::Integer)
        return Vector2(vec.x * int, vec.y * int)
    end
    
    function Base.:*(vec::Vector2, float::Float64)
        return Vector2(vec.x * float, vec.y * float)
    end
    
    function Base.:*(float::Float64, vec::Vector2)
        return Vector2(vec.x * float, vec.y * float)
    end

    function Base.:/(vec::Vector2, vec1::Vector2)
        return Vector2(vec.x / vec1.x, vec.y / vec1.y)
    end
    
    function Base.:/(vec::Vector2, float::Float64)
        return Vector2(vec.x / float, round(vec.y / float))
    end
end   
