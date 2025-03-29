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

    export TypeConversions, Vector2, Vector2f, Vector3, Vector3f, Vector4, Vector4f, normalize, distance, Lerp, SmoothLerp

    function normalize(vector::Vector2f)
        magnitude = sqrt(vector.x^2 + vector.y^2)
        return Vector2f(vector.x / magnitude, vector.y / magnitude)
    end

    function distance(a::Vector2f, b::Vector2f)
        return sqrt((b.x - a.x)^2 + (b.y - a.y)^2)
    end
end
