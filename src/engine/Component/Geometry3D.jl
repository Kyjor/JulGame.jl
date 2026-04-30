module Geometry3DModule
    using ..JulGame.SDL2
    using ..JulGame.SDL2.LibSDL2
    using ..Math3DModule
    
    export Vertex3D, Triangle3D, AABB, UV, RenderState

    # Vertex structure for rendering
    mutable struct Vertex3D
        x::Float64
        y::Float64
        z::Float64
        color::SDL_Color
        u::Float64
        v::Float64

        function Vertex3D(x::Float64, y::Float64, z::Float64, color::SDL_Color, u::Float64 = 0.0, v::Float64 = 0.0)
            new(x, y, z, color, u, v)
        end
    end

    # Triangle structure
    mutable struct Triangle3D
        vertices::Vector{Vertex3D}
        texture::Ptr{SDL_Texture}

        function Triangle3D(v1::Vertex3D, v2::Vertex3D, v3::Vertex3D, texture::Ptr{SDL_Texture} = C_NULL)
            new([v1, v2, v3], texture)
        end
    end

    # AABB structure
    mutable struct AABB
        min::Vec3D
        max::Vec3D

        function AABB(min::Vec3D, max::Vec3D)
            new(min, max)
        end
    end

    # UV coordinate structure
    mutable struct UV
        u::Float64
        v::Float64
        
        function UV(u::Float64 = 0.0, v::Float64 = 0.0)
            new(u, v)
        end
    end

    # Render state
    mutable struct RenderState
        transform::Mat4x4
        fill_color::SDL_Color
        stroke_color::SDL_Color

        function RenderState()
            new(Mat4x4(), SDL_Color(255, 255, 255, 255), SDL_Color(0, 0, 0, 255))
        end
    end

end 