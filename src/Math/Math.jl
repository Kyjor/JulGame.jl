"""
# Math Module

This module provides mathematical utilities and data structures for the game engine.
"""
module Math
    include("TypeConversions.jl")
    include("Vector2.jl")
    include("Vector3.jl")
    include("Vector4.jl")
    include("Lerp.jl")

    export TypeConversions, Vector2, Vector2f, Vector3, Vector3f, Vector4, Vector4f, normalize, distance, Lerp, SmoothLerp, to_vector3

    function normalize(vector::Vector2f)
        magnitude = sqrt(vector.x^2 + vector.y^2)
        return Vector2f(vector.x / magnitude, vector.y / magnitude)
    end

    function distance(a::Vector2f, b::Vector2f)
        return sqrt((b.x - a.x)^2 + (b.y - a.y)^2)
    end

    """
    Convert a Vector2 to Vector3, setting z to 0
    """
    function to_vector3(vec::_Vector2{T}) where T
        return _Vector3{T}(vec.x, vec.y, 0)
    end

    """
    Convert a Vector2 to Vector3, setting z to 0
    """
    function Base.convert(::Type{_Vector3{T}}, vec::_Vector2{T}) where T
        return _Vector3{T}(vec.x, vec.y, 0)
    end
end
