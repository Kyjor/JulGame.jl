module Math3DModule
    export Vec3D, Mat4x4

    # 3D Vector structure
    mutable struct Vec3D
        x::Float64
        y::Float64
        z::Float64
        w::Float64

        function Vec3D(x::Number = 0.0, y::Number = 0.0, z::Number = 0.0, w::Number = 1.0)
            new(convert(Float64, x), convert(Float64, y), convert(Float64, z), convert(Float64, w))
        end
    end

    # Vector operations
    Base.:+(a::Vec3D, b::Vec3D) = Vec3D(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w)
    Base.:-(a::Vec3D, b::Vec3D) = Vec3D(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w)
    Base.:*(a::Vec3D, s::Number) = Vec3D(a.x * s, a.y * s, a.z * s, a.w * s)
    Base.:*(s::Number, a::Vec3D) = a * s
    Base.:-(a::Vec3D) = Vec3D(-a.x, -a.y, -a.z, -a.w)
    # Scalar division for Vec3D
    Base.:/(a::Vec3D, s::Number) = Vec3D(a.x / s, a.y / s, a.z / s, a.w / s)

    function dot(a::Vec3D, b::Vec3D)::Float64
        return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
    end

    function cross(a::Vec3D, b::Vec3D)::Vec3D
        return Vec3D(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x,
            0.0 # w component is 0 for a direction vector
        )
    end

    function length_of(v::Vec3D)::Float64
        return sqrt(v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w)
    end

    function normalize(v::Vec3D, new_length::Float64 = 1.0)::Vec3D
        len = length_of(v)
        if len == 0.0
            return Vec3D(0, 0, 0, 0)
        end
        return v * (new_length / len)
    end

    function min_pairwise(a::Vec3D, b::Vec3D)::Vec3D
        return Vec3D(min(a.x, b.x), min(a.y, b.y), min(a.z, b.z), min(a.w, b.w))
    end

    function max_pairwise(a::Vec3D, b::Vec3D)::Vec3D
        return Vec3D(max(a.x, b.x), max(a.y, b.y), max(a.z, b.z), max(a.w, b.w))
    end

    # 4x4 Matrix structure
    mutable struct Mat4x4
        rows::Vector{Vec3D}

        function Mat4x4()
            new([Vec3D(1, 0, 0, 0), Vec3D(0, 1, 0, 0), Vec3D(0, 0, 1, 0), Vec3D(0, 0, 0, 1)])
        end

        function Mat4x4(r1::Vec3D, r2::Vec3D, r3::Vec3D, r4::Vec3D)
            new([r1, r2, r3, r4])
        end
    end

    # Matrix operations
    function Base.:*(m::Mat4x4, v::Vec3D)::Vec3D
        return Vec3D(
            dot(m.rows[1], v),
            dot(m.rows[2], v),
            dot(m.rows[3], v),
            dot(m.rows[4], v)
        )
    end

    function Base.:*(a::Mat4x4, b::Mat4x4)::Mat4x4
        # Get columns of b
        col1 = Vec3D(b.rows[1].x, b.rows[2].x, b.rows[3].x, b.rows[4].x)
        col2 = Vec3D(b.rows[1].y, b.rows[2].y, b.rows[3].y, b.rows[4].y)
        col3 = Vec3D(b.rows[1].z, b.rows[2].z, b.rows[3].z, b.rows[4].z)
        col4 = Vec3D(b.rows[1].w, b.rows[2].w, b.rows[3].w, b.rows[4].w)

        return Mat4x4(
            Vec3D(dot(a.rows[1], col1), dot(a.rows[1], col2), dot(a.rows[1], col3), dot(a.rows[1], col4)),
            Vec3D(dot(a.rows[2], col1), dot(a.rows[2], col2), dot(a.rows[2], col3), dot(a.rows[2], col4)),
            Vec3D(dot(a.rows[3], col1), dot(a.rows[3], col2), dot(a.rows[3], col3), dot(a.rows[3], col4)),
            Vec3D(dot(a.rows[4], col1), dot(a.rows[4], col2), dot(a.rows[4], col3), dot(a.rows[4], col4))
        )
    end

    # Matrix creation functions
    function translation_matrix(x::Float64, y::Float64, z::Float64)::Mat4x4
        return Mat4x4(
            Vec3D(1, 0, 0, x),
            Vec3D(0, 1, 0, y),
            Vec3D(0, 0, 1, z),
            Vec3D(0, 0, 0, 1)
        )
    end

    function scaling_matrix(x::Float64, y::Float64, z::Float64)::Mat4x4
        return Mat4x4(
            Vec3D(x, 0, 0, 0),
            Vec3D(0, y, 0, 0),
            Vec3D(0, 0, z, 0),
            Vec3D(0, 0, 0, 1)
        )
    end

    function x_rotation_matrix(radians::Float64)::Mat4x4
        c = cos(radians)
        s = sin(radians)
        return Mat4x4(
            Vec3D(1, 0, 0, 0),
            Vec3D(0, c, -s, 0),
            Vec3D(0, s, c, 0),
            Vec3D(0, 0, 0, 1)
        )
    end

    function y_rotation_matrix(radians::Float64)::Mat4x4
        c = cos(radians)
        s = sin(radians)
        return Mat4x4(
            Vec3D(c, 0, s, 0),
            Vec3D(0, 1, 0, 0),
            Vec3D(-s, 0, c, 0),
            Vec3D(0, 0, 0, 1)
        )
    end

    function z_rotation_matrix(radians::Float64)::Mat4x4
        c = cos(radians)
        s = sin(radians)
        return Mat4x4(
            Vec3D(c, -s, 0, 0),
            Vec3D(s, c, 0, 0),
            Vec3D(0, 0, 1, 0),
            Vec3D(0, 0, 0, 1)
        )
    end

    function rotation_matrix(x::Float64, y::Float64, z::Float64)::Mat4x4
        return x_rotation_matrix(x) * y_rotation_matrix(y) * z_rotation_matrix(z)
    end

    function viewport_matrix(width::Float64, height::Float64)::Mat4x4
        return Mat4x4(
            Vec3D(width / 2.0, 0, 0, width / 2.0),
            Vec3D(0, -height / 2.0, 0, height / 2.0),
            Vec3D(0, 0, -1, 0),
            Vec3D(0, 0, 0, 1)
        )
    end

    function perspective_matrix(fov::Float64, aspect::Float64, near::Float64, far::Float64)::Mat4x4
        f = 1.0 / tan(fov / 2.0)
        nf = 1.0 / (near - far)
        return Mat4x4(
            Vec3D(f / aspect, 0, 0, 0),
            Vec3D(0, f, 0, 0),
            Vec3D(0, 0, (far + near) * nf, 2 * far * near * nf),
            Vec3D(0, 0, -1, 0)
        )
    end

    # Perspective divide
    function perspective_divide!(v::Vec3D)
        if v.w != 0.0
            v.x /= v.w
            v.y /= v.w
            v.z /= v.w
            v.w = 1.0
        end
    end

end 