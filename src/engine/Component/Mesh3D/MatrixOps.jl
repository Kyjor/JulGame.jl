module MatrixOps
    using ..Mesh3DModule
    
    export mat4x4,
           matrix_make_identity,
           matrix_make_rotation_x,
           matrix_make_rotation_y,
           matrix_make_rotation_z,
           matrix_make_translation,
           matrix_make_scale,
           matrix_make_projection,
           matrix_multiply_matrix,
           matrix_multiply_vector,
           matrix_point_at,
           matrix_quick_inverse,
           vector_add,
           vector_sub,
           vector_mul,
           vector_div,
           vector_dot_product,
           vector_normalize,
           vector_length,
           vector_cross_product,
           vector_intersect_plane

    mutable struct mat4x4
        m::Array{Float64, 2}
        function mat4x4(m = fill(0.0, (4, 4)))
            new(m)
        end
    end

    function matrix_make_identity()::mat4x4
        matrix = mat4x4()
        matrix.m[1, 1] = 1.0
        matrix.m[2, 2] = 1.0
        matrix.m[3, 3] = 1.0
        matrix.m[4, 4] = 1.0
        return matrix
    end

    function matrix_make_rotation_x(fAngleRad::Float64)::mat4x4
        matrix = mat4x4()
        matrix.m[1, 1] = 1.0
        matrix.m[2, 2] = cos(fAngleRad)
        matrix.m[2, 3] = sin(fAngleRad)
        matrix.m[3, 2] = -sin(fAngleRad)
        matrix.m[3, 3] = cos(fAngleRad)
        matrix.m[4, 4] = 1.0
        return matrix
    end

    function matrix_make_rotation_y(fAngleRad::Float64)::mat4x4
        matrix = mat4x4()
        matrix.m[1, 1] = cos(fAngleRad)
        matrix.m[1, 3] = sin(fAngleRad)
        matrix.m[3, 1] = -sin(fAngleRad)
        matrix.m[2, 2] = 1.0
        matrix.m[3, 3] = cos(fAngleRad)
        matrix.m[4, 4] = 1.0
        return matrix
    end

    function matrix_make_rotation_z(fAngleRad::Float64)::mat4x4
        matrix = mat4x4()
        matrix.m[1, 1] = cos(fAngleRad)
        matrix.m[1, 2] = sin(fAngleRad)
        matrix.m[2, 1] = -sin(fAngleRad)
        matrix.m[2, 2] = cos(fAngleRad)
        matrix.m[3, 3] = 1.0
        matrix.m[4, 4] = 1.0
        return matrix
    end

    function matrix_make_translation(x::Float64, y::Float64, z::Float64)::mat4x4
        matrix = mat4x4()
        matrix.m[1, 1] = 1.0
        matrix.m[2, 2] = 1.0
        matrix.m[3, 3] = 1.0
        matrix.m[4, 4] = 1.0
        matrix.m[4, 1] = x
        matrix.m[4, 2] = y
        matrix.m[4, 3] = z
        return matrix
    end

    function matrix_make_scale(x::Float64, y::Float64, z::Float64)::mat4x4
        matrix = mat4x4()
        matrix.m[1, 1] = x
        matrix.m[2, 2] = y
        matrix.m[3, 3] = z
        matrix.m[4, 4] = 1.0
        return matrix
    end

    function matrix_make_projection(fFovDegrees::Float64, fAspectRatio::Float64, fNear::Float64, fFar::Float64)::mat4x4
        fFovRad = 1.0 / tan(fFovDegrees * 0.5 / 180.0 * 3.14159)
        matrix = mat4x4()
        matrix.m[1, 1] = fAspectRatio * fFovRad
        matrix.m[2, 2] = fFovRad
        matrix.m[3, 3] = (fFar / (fFar - fNear))
        matrix.m[4, 3] = (-fFar * fNear) / (fFar - fNear)
        matrix.m[3, 4] = 1.0
        matrix.m[4, 4] = 0.0
        return matrix
    end

    function matrix_multiply_matrix(m1::mat4x4, m2::mat4x4)::mat4x4
        matrix = mat4x4()
        for c in 1:4
            for r in 1:4
                matrix.m[r, c] = m1.m[r, 1] * m2.m[1, c] + m1.m[r, 2] * m2.m[2, c] + m1.m[r, 3] * m2.m[3, c] + m1.m[r, 4] * m2.m[4, c]
            end
        end
        return matrix
    end

    function matrix_multiply_vector(m::mat4x4, i::Mesh3DModule.vec3d)::Mesh3DModule.vec3d
        v = Mesh3DModule.vec3d(0, 0, 0)
        v.x = i.x * m.m[1, 1] + i.y * m.m[2, 1] + i.z * m.m[3, 1] + i.w * m.m[4, 1]
        v.y = i.x * m.m[1, 2] + i.y * m.m[2, 2] + i.z * m.m[3, 2] + i.w * m.m[4, 2]
        v.z = i.x * m.m[1, 3] + i.y * m.m[2, 3] + i.z * m.m[3, 3] + i.w * m.m[4, 3]
        v.w = i.x * m.m[1, 4] + i.y * m.m[2, 4] + i.z * m.m[3, 4] + i.w * m.m[4, 4]
        return v
    end

    function matrix_point_at(pos::vec3d, target::vec3d, up::vec3d)::mat4x4
        newForward = vector_sub(target, pos)
        newForward = vector_normalize(newForward)

        a = vector_mul(newForward, vector_dot_product(up, newForward))
        newUp = vector_sub(up, a)
        newUp = vector_normalize(newUp)

        newRight = vector_cross_product(newUp, newForward)

        matrix = mat4x4()
        matrix.m[1, 1] = newRight.x; matrix.m[1, 2] = newRight.y; matrix.m[1, 3] = newRight.z; matrix.m[1, 4] = 0.0
        matrix.m[2, 1] = newUp.x; matrix.m[2, 2] = newUp.y; matrix.m[2, 3] = newUp.z; matrix.m[2, 4] = 0.0
        matrix.m[3, 1] = newForward.x; matrix.m[3, 2] = newForward.y; matrix.m[3, 3] = newForward.z; matrix.m[3, 4] = 0.0
        matrix.m[4, 1] = pos.x; matrix.m[4, 2] = pos.y; matrix.m[4, 3] = pos.z; matrix.m[4, 4] = 1.0

        return matrix
    end

    function matrix_quick_inverse(m::mat4x4)::mat4x4
        matrix = mat4x4()
        matrix.m[1, 1] = m.m[1, 1]; matrix.m[1, 2] = m.m[2, 1]; matrix.m[1, 3] = m.m[3, 1]; matrix.m[1, 4] = 0.0
        matrix.m[2, 1] = m.m[1, 2]; matrix.m[2, 2] = m.m[2, 2]; matrix.m[2, 3] = m.m[3, 2]; matrix.m[2, 4] = 0.0
        matrix.m[3, 1] = m.m[1, 3]; matrix.m[3, 2] = m.m[2, 3]; matrix.m[3, 3] = m.m[3, 3]; matrix.m[3, 4] = 0.0
        matrix.m[4, 1] = -(m.m[4, 1] * matrix.m[1, 1] + m.m[4, 2] * matrix.m[2, 1] + m.m[4, 3] * matrix.m[3, 1])
        matrix.m[4, 2] = -(m.m[4, 1] * matrix.m[1, 2] + m.m[4, 2] * matrix.m[2, 2] + m.m[4, 3] * matrix.m[3, 2])
        matrix.m[4, 3] = -(m.m[4, 1] * matrix.m[1, 3] + m.m[4, 2] * matrix.m[2, 3] + m.m[4, 3] * matrix.m[3, 3])
        matrix.m[4, 4] = 1.0
        return matrix
    end

    function vector_add(v1::vec3d, v2::vec3d)::vec3d
        return vec3d(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
    end

    function vector_sub(v1::vec3d, v2::vec3d)::vec3d
        return vec3d(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z)
    end

    function vector_mul(v1::vec3d, k::Float64)::vec3d
        return vec3d(v1.x * k, v1.y * k, v1.z * k)
    end

    function vector_div(v1::vec3d, k::Float64)::vec3d
        return vec3d(v1.x / k, v1.y / k, v1.z / k)
    end

    function vector_dot_product(v1::vec3d, v2::vec3d)::Float64
        return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
    end

    function vector_normalize(v::vec3d)::vec3d
        l = vector_length(v)
        return vec3d(v.x / l, v.y / l, v.z / l)
    end

    function vector_length(v::vec3d)::Float64
        return sqrt(vector_dot_product(v, v))
    end

    function vector_cross_product(v1::vec3d, v2::vec3d)::vec3d
        v = vec3d(0, 0, 0)
        v.x = v1.y * v2.z - v1.z * v2.y
        v.y = v1.z * v2.x - v1.x * v2.z
        v.z = v1.x * v2.y - v1.y * v2.x
        return v
    end

    function vector_intersect_plane(plane_p::vec3d, plane_n::vec3d, lineStart::vec3d, lineEnd::vec3d)::vec3d
        plane_n = vector_normalize(plane_n)
        plane_d = -vector_dot_product(plane_n, plane_p)
        ad = vector_dot_product(lineStart, plane_n)
        bd = vector_dot_product(lineEnd, plane_n)
        t = (-plane_d - ad) / (bd - ad)
        lineStartToEnd = vector_sub(lineEnd, lineStart)
        lineToIntersect = vector_mul(lineStartToEnd, t)
        return vector_add(lineStart, lineToIntersect)
    end
end 