module Mesh3DModule
    using ..JulGame
    using ..JulGame.Math
    using ..JulGame.SDL2
    using ..JulGame.SDL2.LibSDL2
    using ..JulGame.Component
    using ..JulGame.InputModule

    
    export Mesh3D

    export vec3d
    mutable struct vec3d
        x::Float64
        y::Float64
        z::Float64
        w::Float64

        function vec3d(x::Number, y::Number, z::Number, w::Number = 1.0)
            new(convert(Float64, x), convert(Float64, y), convert(Float64, z), convert(Float64, w))
        end
    end




    mutable struct triangle
        p::Vector{vec3d}
        sym::Any
        color::Any
        function triangle(p = [vec3d(0,0,0), vec3d(0,0,0), vec3d(0,0,0)])
            new(p, nothing, nothing)
        end
    end

    mutable struct mesh
        tris::Vector{triangle}
    end

    struct RGB
        r::Int
        g::Int
        b::Int
    end

    include("Mesh3D/MatrixOps.jl")
    using .MatrixOps

    const PIXEL_SOLID = '█'
    const PIXEL_QUARTER = '░'
    const PIXEL_HALF = '▒'
    const PIXEL_THREEQUARTERS = '▓'

    mutable struct Mesh3D
        parent
        layer::Int
        isWorldEntity::Bool
        mesh::mesh
        fNear::Float64
        fFar::Float64
        fFov::Float64
        fYaw::Float64
        fTheta::Float64
        fAspectRatio::Float64
        vCamera::vec3d
        vLookDir::vec3d
        matProj::mat4x4
        matView::mat4x4
        matWorld::mat4x4
        vecTrianglesToRaster::Vector{triangle}

        function Mesh3D()
            this = new()
            this.parent = C_NULL
            this.layer = 0
            this.isWorldEntity = true
            this.mesh = mesh(triangle[])
            this.fNear = 0.1
            this.fFar = 1000.0
            this.fFov = 90.0
            this.fYaw = 0.0
            this.fTheta = 0.0
            this.fAspectRatio = 0.0
            this.vCamera = vec3d(0, 0, 0)
            this.vLookDir = vec3d(0, 0, 0)
            this.matProj = MatrixOps.matrix_make_identity()
            this.matView = MatrixOps.matrix_make_identity()
            this.matWorld = MatrixOps.matrix_make_identity()
            this.vecTrianglesToRaster = []
            return this
        end
    end

    function Component.initialize(this::Mesh3D, main)
        windowSize = main.windowManager.windowSize
        this.fAspectRatio = windowSize.y / windowSize.x
        this.matProj = MatrixOps.matrix_make_projection(this.fFov, this.fAspectRatio, this.fNear, this.fFar)
        this.mesh = create_cube()
    end

    function Component.update(this::Mesh3D, deltaTime::Float64)
        if !this.parent.isActive
            return
        end

        # Camera controls
        vForward = MatrixOps.vector_mul(this.vLookDir, 8.0 * deltaTime)
        
        if InputModule.get_button_held_down("W")
            this.vCamera = MatrixOps.vector_add(this.vCamera, vForward)
        elseif InputModule.get_button_held_down("S")
            this.vCamera = MatrixOps.vector_sub(this.vCamera, vForward)
        end

        if InputModule.get_button_held_down("A")
            this.fYaw -= 2.0 * deltaTime
        elseif InputModule.get_button_held_down("D")
            this.fYaw += 2.0 * deltaTime
        end

        # Update camera view matrix
        vUp = vec3d(0, 1, 0)
        vTarget = vec3d(0, 0, 1)
        matCameraRot = MatrixOps.matrix_make_rotation_y(this.fYaw)
        this.vLookDir = MatrixOps.matrix_multiply_vector(matCameraRot, vTarget)
        vTarget = MatrixOps.vector_add(this.vCamera, this.vLookDir)
        matCamera = MatrixOps.matrix_point_at(this.vCamera, vTarget, vUp)
        this.matView = MatrixOps.matrix_quick_inverse(matCamera)
    end

    function Component.render(this::Mesh3D, main)
        # Clear triangles to raster
        empty!(this.vecTrianglesToRaster)

        # Get world matrix from entity transform
        pos = this.parent.transform.position
        scale = this.parent.transform.scale
        rot = this.parent.transform.rotation

        # Create world matrix
        matTrans = MatrixOps.matrix_make_translation(pos.x, pos.y, 0.0)
        matScale = MatrixOps.matrix_make_scale(scale.x, scale.y, 1.0)
        matRotZ = MatrixOps.matrix_make_rotation_z(rot.z)
        this.matWorld = MatrixOps.matrix_multiply_matrix(matRotZ, matScale)
        this.matWorld = MatrixOps.matrix_multiply_matrix(this.matWorld, matTrans)

        # Process each triangle
        for tri in this.mesh.tris
            triTransformed = triangle()
            triViewed = triangle()
            triProjected = Ref(triangle())

            # Transform triangle vertices
            triTransformed.p[1] = MatrixOps.matrix_multiply_vector(this.matWorld, tri.p[1])
            triTransformed.p[2] = MatrixOps.matrix_multiply_vector(this.matWorld, tri.p[2])
            triTransformed.p[3] = MatrixOps.matrix_multiply_vector(this.matWorld, tri.p[3])

            normal::vec3d = vec3d(0, 0, 0)
			line1::vec3d  = vec3d(0, 0, 0)
			line2::vec3d  = vec3d(0, 0, 0)
	
            # Get lines either side of the triangle
            line1 = MatrixOps.vector_sub(triTransformed.p[2], triTransformed.p[1])
            line2 = MatrixOps.vector_sub(triTransformed.p[3], triTransformed.p[1])
            
			# Take cross product of lines to get normal to triangle surface 
			normal = MatrixOps.vector_cross_product(line1, line2)
	
            # you normally need to normalize a normal!
            normal = MatrixOps.vector_normalize(normal)
            
			# Get Ray from triangle to camera 
			vCameraRay::vec3d = MatrixOps.vector_sub(triTransformed.p[1], this.vCamera)
            if MatrixOps.vector_dot_product(normal, vCameraRay) < 0.0
                # Lighting
                light_direction = vec3d(-0.707, -0.707, -1.0)
                light_direction = MatrixOps.vector_normalize(light_direction)
                dp = MatrixOps.vector_dot_product(normal, light_direction)

                # Convert to view space
                triViewed.p[1] = MatrixOps.matrix_multiply_vector(this.matView, triTransformed.p[1])
                triViewed.p[2] = MatrixOps.matrix_multiply_vector(this.matView, triTransformed.p[2])
                triViewed.p[3] = MatrixOps.matrix_multiply_vector(this.matView, triTransformed.p[3])

                # Clip against near plane
				clipped = Ref([triangle([vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0)]), triangle([vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0)])])
                nClippedTriangles = triangle_clip_against_plane(vec3d(0.0, 0.0, this.fNear), vec3d(0.0, 0.0, 1.0), triViewed, clipped)

                if nClippedTriangles > 0
                    for i in 1:nClippedTriangles
                        # Project triangles
                        triProjected.p[1] = MatrixOps.matrix_multiply_vector(this.matProj, clipped[][i].p[1])
                        triProjected.p[2] = MatrixOps.matrix_multiply_vector(this.matProj, clipped[][i].p[2])
                        triProjected.p[3] = MatrixOps.matrix_multiply_vector(this.matProj, clipped[][i].p[3])

                        # Scale into view
                        triProjected.p[1] = MatrixOps.vector_div(triProjected.p[1], triProjected.p[1].w)
                        triProjected.p[2] = MatrixOps.vector_div(triProjected.p[2], triProjected.p[2].w)
                        triProjected.p[3] = MatrixOps.vector_div(triProjected.p[3], triProjected.p[3].w)

                        # Scale to screen
                        windowSize = main.windowManager.windowSize
                        vOffsetView = vec3d(1, 1, 0)
                        triProjected.p[1] = MatrixOps.vector_add(triProjected.p[1], vOffsetView)
                        triProjected.p[2] = MatrixOps.vector_add(triProjected.p[2], vOffsetView)
                        triProjected.p[3] = MatrixOps.vector_add(triProjected.p[3], vOffsetView)

                        triProjected.p[1].x *= 0.5 * windowSize.x
                        triProjected.p[1].y *= 0.5 * windowSize.y
                        triProjected.p[2].x *= 0.5 * windowSize.x
                        triProjected.p[2].y *= 0.5 * windowSize.y
                        triProjected.p[3].x *= 0.5 * windowSize.x
                        triProjected.p[3].y *= 0.5 * windowSize.y

                        # Set color based on lighting
                        r = round(Int, 255 * max(0.0, dp))
                        g = round(Int, 255 * max(0.0, dp))
                        b = round(Int, 255 * max(0.0, dp))
                        triProjected.color = SDL_Color(r, g, b, 255)

                        push!(this.vecTrianglesToRaster, triProjected)
                    end
                end
            end
        end

        # Sort triangles by Z depth
        sort!(this.vecTrianglesToRaster, by = avg_z, rev = true)

        println(this.vecTrianglesToRaster)
        # Render triangles
        for triToRaster in this.vecTrianglesToRaster
            if isnan(triToRaster.p[1].x) || isnan(triToRaster.p[1].y) ||
               isnan(triToRaster.p[2].x) || isnan(triToRaster.p[2].y) ||
               isnan(triToRaster.p[3].x) || isnan(triToRaster.p[3].y)
                continue
            end

            # Clip against screen edges
            clipped = Ref([triangle(), triangle()])
            listTriangles = [triToRaster]
            nNewTriangles = 1

            for i in 1:4
                nTrisToAdd = 0
                while nNewTriangles > 0
                    test = listTriangles[1]
                    popfirst!(listTriangles)
                    nNewTriangles -= 1

                    #  Clip it against a plane. We only need to test each 
					#  subsequent plane, against subsequent new triangles
					#  as all triangles after a plane clip are guaranteed
					#  to lie on the inside of the plane. I like how this
					#  comment is almost completely and utterly justified

                    if i == 1
                        nTrisToAdd = triangle_clip_against_plane(vec3d(0.0, 0.0, 0.0), vec3d(0.0, 1.0, 0.0), test, clipped)
                    elseif i == 2
                        nTrisToAdd = triangle_clip_against_plane(vec3d(0.0, main.windowManager.windowSize.y - 1.0, 0.0), vec3d(0.0, -1.0, 0.0), test, clipped)
                    elseif i == 3
                        nTrisToAdd = triangle_clip_against_plane(vec3d(0.0, 0.0, 0.0), vec3d(1.0, 0.0, 0.0), test, clipped)
                    elseif i == 4
                        nTrisToAdd = triangle_clip_against_plane(vec3d(main.windowManager.windowSize.x - 1.0, 0.0, 0.0), vec3d(-1.0, 0.0, 0.0), test, clipped)
                    end

                    if nTrisToAdd > 0
                        for w in 1:nTrisToAdd
                            push!(listTriangles, clipped[][w])
                        end
                    end
                end
                nNewTriangles = length(listTriangles)
            end

            println(length(listTriangles))
            # Draw triangles
            for tri in listTriangles
                sdl_verts = [
                    SDL_Vertex(SDL_FPoint(tri.p[1].x, tri.p[1].y), tri.color, SDL_FPoint(0, 0)),
                    SDL_Vertex(SDL_FPoint(tri.p[2].x, tri.p[2].y), tri.color, SDL_FPoint(0, 0)),
                    SDL_Vertex(SDL_FPoint(tri.p[3].x, tri.p[3].y), tri.color, SDL_FPoint(0, 0))
                ]
                println(sdl_verts)
                SDL_RenderGeometry(JulGame.Renderer, C_NULL, sdl_verts, length(sdl_verts), C_NULL, 0)
                
                if JulGame.IS_DEBUG
                    SDL_RenderDrawLine(
                        JulGame.Renderer,
                        round(tri.p[1].x), round(tri.p[1].y),
                        round(tri.p[2].x), round(tri.p[2].y)
                    )
		
					SDL_RenderDrawLine(
						JulGame.Renderer,
						round(tri.p[2].x), round(tri.p[2].y),
						round(tri.p[3].x), round(tri.p[3].y)
					)
		
                    SDL_RenderDrawLine(
                        JulGame.Renderer,
                        round(tri.p[3].x), round(tri.p[3].y),
                        round(tri.p[1].x), round(tri.p[1].y)
                    )
                end
            end
        end
    end

    function Component.destroy(this::Mesh3D)
        empty!(this.mesh.tris)
        empty!(this.vecTrianglesToRaster)
    end

    function load_from_object_file(this::Mesh3D, file_name::String)
        f = open(file_name, "r")
        if f === nothing
            return false
        end

        empty!(this.mesh.tris)
        verts = Vector{vec3d}()

        while !eof(f)
            line = readline(f)
            s = split(line)
            
            if !isempty(s) && s[1] == "v"
                v = vec3d(parse(Float64, s[2]), parse(Float64, s[3]), parse(Float64, s[4]))
                push!(verts, v)
            end

            if !isempty(s) && s[1] == "f"
                tri = triangle([
                    verts[parse(Int, s[2])],
                    verts[parse(Int, s[3])],
                    verts[parse(Int, s[4])]
                ])
                push!(this.mesh.tris, tri)
            end
        end

        close(f)
        return true
    end

    function avg_z(t::triangle)
        z_vals = [p.z for p in t.p]
        return sum(z_vals) / length(z_vals)
    end

    function triangle_clip_against_plane(plane_p::vec3d, plane_n::vec3d, in_tri::Ref{triangle}, out_tris::Ref{Vector{triangle}})::Int
        plane_n = MatrixOps.vector_normalize(plane_n)

        dist = (p::vec3d) -> begin
            n = MatrixOps.vector_normalize(p)
            return plane_n.x * p.x + plane_n.y * p.y + plane_n.z * p.z - MatrixOps.vector_dot_product(plane_n, plane_p)
        end

        inside_points = Vector{vec3d}(undef, 3)
        nInsidePointCount = 0

        outside_points = Vector{vec3d}(undef, 3)
        nOutsidePointCount = 0

        d0 = dist(in_tri[].p[1])
        d1 = dist(in_tri[].p[2])
        d2 = dist(in_tri[].p[3])

        if d0 >= 0
            inside_points[nInsidePointCount+1] = in_tri[].p[1]
            nInsidePointCount += 1
        else
            outside_points[nOutsidePointCount+1] = in_tri[].p[1]
            nOutsidePointCount += 1
        end

        if d1 >= 0
            inside_points[nInsidePointCount+1] = in_tri[].p[2]
            nInsidePointCount += 1
        else
            outside_points[nOutsidePointCount+1] = in_tri[].p[2]
            nOutsidePointCount += 1
        end

        if d2 >= 0
            inside_points[nInsidePointCount+1] = in_tri[].p[3]
            nInsidePointCount += 1
        else
            outside_points[nOutsidePointCount+1] = in_tri[].p[3]
            nOutsidePointCount += 1
        end

        if nInsidePointCount == 0
            return 0
        end

        if nInsidePointCount == 3
            out_tris[][1] = in_tri[]
            return 1
        end

        if nInsidePointCount == 1 && nOutsidePointCount == 2
            out_tris[][1].color = in_tri[].color
            out_tris[][1].sym = in_tri[].sym
            
            out_tris[][1].p[2] = MatrixOps.vector_intersect_plane(plane_p, plane_n, inside_points[1], outside_points[1])
            out_tris[][1].p[3] = MatrixOps.vector_intersect_plane(plane_p, plane_n, inside_points[1], outside_points[2])
        
            return 1
        end

        if nInsidePointCount == 2 && nOutsidePointCount == 1
            out_tris[][1].color = in_tri[].color
            out_tris[][1].sym = in_tri[].sym
            
            out_tris[][2].color = in_tri[].color
            out_tris[][2].sym = in_tri[].sym

            out_tris[][1].p[1] = inside_points[1]
            out_tris[][1].p[2] = inside_points[2]
            out_tris[][1].p[3] = MatrixOps.vector_intersect_plane(plane_p, plane_n, inside_points[1], outside_points[1])
            
            out_tris[][2].p[1] = inside_points[2]
            out_tris[][2].p[2] = out_tris[][1].p[3]
            out_tris[][2].p[3] = MatrixOps.vector_intersect_plane(plane_p, plane_n, inside_points[2], outside_points[1])

            return 2
        end
    end

    function create_cube()
        meshCube = mesh(triangle[
            # SOUTH
            triangle([ vec3d(0.0, 0.0, 0.0), vec3d(0.0, 1.0, 0.0), vec3d(1.0, 1.0, 0.0)]),
            triangle([ vec3d(0.0, 0.0, 0.0), vec3d(1.0, 1.0, 0.0), vec3d(1.0, 0.0, 0.0)]),
            triangle([ vec3d(0.0, 0.0, 0.0), vec3d(1.0, 1.0, 0.0), vec3d(1.0, 0.0, 0.0)]),
            # EAST
            triangle([ vec3d(1.0, 0.0, 0.0), vec3d(1.0, 1.0, 0.0), vec3d(1.0, 1.0, 1.0)]),
            triangle([ vec3d(1.0, 0.0, 0.0), vec3d(1.0, 1.0, 1.0), vec3d(1.0, 0.0, 1.0)]),
            # NORTH
            triangle([ vec3d(1.0, 0.0, 1.0), vec3d(1.0, 1.0, 1.0), vec3d(0.0, 1.0, 1.0)]),
            triangle([ vec3d(1.0, 0.0, 1.0), vec3d(0.0, 1.0, 1.0), vec3d(0.0, 0.0, 1.0)]),
            # WEST
            triangle([ vec3d(0.0, 0.0, 1.0), vec3d(0.0, 1.0, 1.0), vec3d(0.0, 1.0, 0.0)]),
            triangle([ vec3d(0.0, 0.0, 1.0), vec3d(0.0, 1.0, 0.0), vec3d(0.0, 0.0, 0.0)]),
            # TOP
            triangle([ vec3d(0.0, 1.0, 0.0), vec3d(0.0, 1.0, 1.0), vec3d(1.0, 1.0, 1.0)]),
            triangle([ vec3d(0.0, 1.0, 0.0), vec3d(1.0, 1.0, 1.0), vec3d(1.0, 1.0, 0.0)]),
            # BOTTOM
            triangle([ vec3d(1.0, 0.0, 1.0), vec3d(0.0, 0.0, 1.0), vec3d(0.0, 0.0, 0.0)]),
            triangle([ vec3d(1.0, 0.0, 1.0), vec3d(0.0, 0.0, 0.0), vec3d(1.0, 0.0, 0.0)]),
        ])
        return meshCube
    end
end 