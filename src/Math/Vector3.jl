struct Vector3
    x::Integer
    y::Integer
    z::Integer

    #default constructor
    Vector3() = new(0, 0, 0)
    Vector3(value::Number) = new(convert(Integer, round(value)), convert(Integer, round(value)), convert(Integer, round(value)))
    Vector3(x::Number, y::Number, z::Number) = new(convert(Integer, round(x)), convert(Integer, round(y)), convert(Integer, round(z)))

    #operators 
    function Base.:+(vec::Vector3, vec1::Vector3)
        return Vector3(vec.x + vec1.x, vec.y + vec1.y, vec.z + vec1.z)
    end

    function Base.:-(vec::Vector3, vec1::Vector3)
        return Vector3(vec.x - vec1.x, vec.y - vec1.y, vec.z - vec1.z)
    end

    function Base.:*(vec::Vector3, vec1::Vector3)
        return Vector3(vec.x * vec1.x, vec.y * vec1.y, vec.z * vec1.z)
    end

    function Base.:*(vec::Vector3, int::Integer)
        return Vector3(vec.x * int, vec.y * int, vec.z * int)
    end
    
    function Base.:*(vec::Vector3, float::Float64)
        return Vector3(vec.x * float, vec.y * float, vec.z * float)
    end
    
    function Base.:*(float::Float64, vec::Vector3)
        return Vector3(vec.x * float, vec.y * float, vec.z * float)
    end

    function Base.:/(vec::Vector3, float::Float64)
        return Vector3(round(vec.x / float), round(vec.y / float), round(vec.z / float))
    end

    function Base.:/(vec::Vector3, int::Integer)
        return Vector3(vec.x / int, vec.y / int, vec.z / int)
    end

    function Base.:/(vec::Vector3, vec1::Vector3)
        return Vector3(vec.x / vec1.x, vec.y / vec1.y, vec.z / vec1.z)
    end
end   
