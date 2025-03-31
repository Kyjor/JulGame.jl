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
        texCoords::Vector{vec3d}
        function triangle(p = [vec3d(0,0,0), vec3d(0,0,0), vec3d(0,0,0)])
            new(p, nothing, nothing, [vec3d(0,0,0), vec3d(0,0,0), vec3d(0,0,0)])
        end
    end

    mutable struct VertexData
        position::vec3d
        normal::vec3d
        texCoord::vec3d
    end

    const PIXEL_SOLID = '█'
    const PIXEL_QUARTER = '░'
    const PIXEL_HALF = '▒'
    const PIXEL_THREEQUARTERS = '▓'

    # Texture mapping modes
    const TEXTURE_MODE_REPEAT = 0
    const TEXTURE_MODE_CLAMP = 1
    const TEXTURE_MODE_MIRROR = 2

    # Texture filtering modes
    const TEXTURE_FILTER_NEAREST = 0
    const TEXTURE_FILTER_LINEAR = 1
    const TEXTURE_FILTER_ANISOTROPIC = 2

    # Texture types
    const TEXTURE_TYPE_DIFFUSE = 0
    const TEXTURE_TYPE_NORMAL = 1
    const TEXTURE_TYPE_SPECULAR = 2
    const TEXTURE_TYPE_EMISSIVE = 3
    const TEXTURE_TYPE_AMBIENT = 4

    mutable struct Texture
        surface::Ptr{SDL_Surface}
        texture::Ptr{SDL_Texture}
        width::Int
        height::Int
        mode::Int
        filter::Int
        type::Int

        function Texture(surface::Ptr{SDL_Surface}, mode::Int = TEXTURE_MODE_REPEAT, 
                        filter::Int = TEXTURE_FILTER_LINEAR, type::Int = TEXTURE_TYPE_DIFFUSE)
            texture = SDL_CreateTextureFromSurface(JulGame.Renderer, surface)
            if texture == C_NULL
                error("Failed to create texture from surface")
            end
            
            # Set texture filtering
            if filter == TEXTURE_FILTER_LINEAR
                SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "1")
            else
                SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0")
            end
            
            width = surface.w
            height = surface.h
            new(surface, texture, width, height, mode, filter, type)
        end
    end

    mutable struct Material
        name::String
        ambient::vec3d
        diffuse::vec3d
        specular::vec3d
        shininess::Float64
        textures::Dict{Int, Texture}
        textureMode::Int

        function Material(name::String = "default")
            new(name, vec3d(0.2, 0.2, 0.2), vec3d(0.8, 0.8, 0.8), 
                vec3d(0.0, 0.0, 0.0), 0.0, Dict{Int, Texture}(), TEXTURE_MODE_REPEAT)
        end
    end

    function load_texture(file_path::String; 
                         mode::Int = TEXTURE_MODE_REPEAT,
                         filter::Int = TEXTURE_FILTER_LINEAR,
                         type::Int = TEXTURE_TYPE_DIFFUSE)::Texture
        # Get file extension
        ext = lowercase(splitext(file_path)[2])
        
        # Load texture based on format
        surface = if ext == ".bmp"
            SDL_LoadBMP(file_path)
        elseif ext == ".png"
            SDL_LoadPNG(file_path)
        elseif ext == ".jpg" || ext == ".jpeg"
            SDL_LoadJPG(file_path)
        else
            error("Unsupported texture format: $ext")
        end

        if surface == C_NULL
            error("Failed to load texture: $file_path")
        end

        return Texture(surface, mode, filter, type)
    end

    function apply_texture_mode(tex_coord::vec3d, texture::Texture)::vec3d
        u = tex_coord.x
        v = tex_coord.y

        if texture.mode == TEXTURE_MODE_REPEAT
            u = mod(u, 1.0)
            v = mod(v, 1.0)
        elseif texture.mode == TEXTURE_MODE_CLAMP
            u = clamp(u, 0.0, 1.0)
            v = clamp(v, 0.0, 1.0)
        elseif texture.mode == TEXTURE_MODE_MIRROR
            u = mod(u, 2.0)
            v = mod(v, 2.0)
            if u > 1.0
                u = 2.0 - u
            end
            if v > 1.0
                v = 2.0 - v
            end
        end

        return vec3d(u, v, 0.0)
    end

    mutable struct mesh
        tris::Vector{triangle}
        materials::Dict{String, Material}
        currentMaterial::String

        function mesh(tris::Vector{triangle} = triangle[], materials::Dict{String, Material} = Dict{String, Material}(), currentMaterial::String = "default")
            new(tris, materials, currentMaterial)
        end
    end

    struct RGB
        r::Int
        g::Int
        b::Int
    end

    include("Mesh3D/MatrixOps.jl")
    using .MatrixOps

    const SUPPORTED_FORMATS = Dict(
        ".obj" => "Wavefront OBJ",
        ".fbx" => "Autodesk FBX",
        ".3ds" => "3D Studio",
        ".dae" => "Collada DAE"
    )

    mutable struct Mesh3D
        parent
        layer::Int
        isWorldEntity::Bool
        mesh::mesh
        fNear::Float64
        fFar::Float64
        fFov::Float64
        fAspectRatio::Float64
        matProj::mat4x4
        matWorld::mat4x4
        vecTrianglesToRaster::Vector{triangle}
        fileFormat::String

        function Mesh3D()
            this = new()
            this.parent = C_NULL
            this.layer = 0
            this.isWorldEntity = true
            this.mesh = mesh()
            this.fNear = 0.1
            this.fFar = 1000.0
            this.fFov = 90.0
            this.fAspectRatio = 0.0
            this.matProj = MatrixOps.matrix_make_identity()
            this.matWorld = MatrixOps.matrix_make_identity()
            this.vecTrianglesToRaster = []
            this.fileFormat = ""
            return this
        end

        function Mesh3D(file_path::String; fNear::Float64=0.1, fFar::Float64=1000.0, fFov::Float64=90.0)
            this = new()
            this.parent = C_NULL
            this.layer = 0
            this.isWorldEntity = true
            this.mesh = mesh(triangle[])
            this.fNear = fNear
            this.fFar = fFar
            this.fFov = fFov
            this.fAspectRatio = 0.0
            this.matProj = MatrixOps.matrix_make_identity()
            this.matWorld = MatrixOps.matrix_make_identity()
            this.vecTrianglesToRaster = []
            
            # Detect and store the file format
            this.fileFormat = detect_file_format(file_path)
            
            # Load the mesh from the object file
            if !load_from_object_file(this, file_path)
                error("Failed to load mesh from file: $file_path")
            end
            
            return this
        end
    end

    function detect_file_format(file_path::String)::String
        ext = lowercase(splitext(file_path)[2])
        if haskey(SUPPORTED_FORMATS, ext)
            return ext
        end
        error("Unsupported file format. Supported formats are: $(join(keys(SUPPORTED_FORMATS), ", "))")
    end

    function load_from_obj(this::Mesh3D, file_path::String)::Bool
        f = open(file_path, "r")
        if f === nothing
            return false
        end

        empty!(this.mesh.tris)
        this.mesh.materials = Dict{String, Material}()
        this.mesh.currentMaterial = "default"

        # Store all vertex data
        vertices = Vector{VertexData}()
        normals = Vector{vec3d}()
        texCoords = Vector{vec3d}()
        faces = Vector{Vector{Int}}()
        faceTexCoords = Vector{Vector{Int}}()

        while !eof(f)
            line = readline(f)
            s = split(line)
            
            if isempty(s)
                continue
            end

            if s[1] == "v"  # Vertex position
                v = vec3d(parse(Float64, s[2]), parse(Float64, s[3]), parse(Float64, s[4]))
                push!(vertices, VertexData(v, vec3d(0,0,0), vec3d(0,0,0)))
            elseif s[1] == "vn"  # Vertex normal
                n = vec3d(parse(Float64, s[2]), parse(Float64, s[3]), parse(Float64, s[4]))
                push!(normals, n)
            elseif s[1] == "vt"  # Texture coordinate
                t = vec3d(parse(Float64, s[2]), parse(Float64, s[3]), 0.0)
                push!(texCoords, t)
            elseif s[1] == "f"  # Face
                # Parse face indices (vertex/texture/normal)
                face_indices = Vector{Int}()
                face_tex_indices = Vector{Int}()
                for i in 2:length(s)
                    indices = split(s[i], "/")
                    if length(indices) >= 1
                        push!(face_indices, parse(Int, indices[1]))
                    end
                    if length(indices) >= 2 && !isempty(indices[2])
                        push!(face_tex_indices, parse(Int, indices[2]))
                    end
                end
                push!(faces, face_indices)
                push!(faceTexCoords, face_tex_indices)
            elseif s[1] == "usemtl"  # Material
                this.mesh.currentMaterial = s[2]
            elseif s[1] == "mtllib"  # Material library
                # TODO: Load material library
                # For now, we'll just ignore it
            end
        end

        # Create triangles from faces
        for (i, face) in enumerate(faces)
            if length(face) >= 3
                # Create a triangle from the first three vertices
                tri = triangle([
                    vertices[face[1]].position,
                    vertices[face[2]].position,
                    vertices[face[3]].position
                ])
                
                # Add texture coordinates if available
                if i <= length(faceTexCoords) && !isempty(faceTexCoords[i])
                    tri.texCoords = [
                        texCoords[faceTexCoords[i][1]],
                        texCoords[faceTexCoords[i][2]],
                        texCoords[faceTexCoords[i][3]]
                    ]
                end
                
                push!(this.mesh.tris, tri)
            end
        end

        close(f)
        return true
    end

    function load_from_fbx(this::Mesh3D, file_path::String)::Bool
        # TODO: Implement FBX loading
        # This would require a FBX parsing library
        error("FBX loading not yet implemented")
    end

    function load_from_3ds(this::Mesh3D, file_path::String)::Bool
        # TODO: Implement 3DS loading
        error("3DS loading not yet implemented")
    end

    function load_from_dae(this::Mesh3D, file_path::String)::Bool
        # TODO: Implement Collada DAE loading
        error("Collada DAE loading not yet implemented")
    end

    function load_from_object_file(this::Mesh3D, file_path::String)::Bool
        format = detect_file_format(file_path)
        
        if format == ".obj"
            return load_from_obj(this, file_path)
        elseif format == ".fbx"
            return load_from_fbx(this, file_path)
        elseif format == ".3ds"
            return load_from_3ds(this, file_path)
        elseif format == ".dae"
            return load_from_dae(this, file_path)
        end
        
        return false
    end

    function Component.initialize(this::Mesh3D, main)
        windowSize = main.windowManager.windowSize
        this.fAspectRatio = windowSize.y / windowSize.x
        this.matProj = MatrixOps.matrix_make_projection(this.fFov, this.fAspectRatio, this.fNear, this.fFar)
        this.mesh = create_cube()
        
        # Move the cube forward
        if this.parent !== nothing
            this.parent.transform.position = Math.Vector3f(0.0, 0.0, 5.0)
        end
    end

    function Component.update(this::Mesh3D, deltaTime::Float64)
        if !this.parent.isActive
            return
        end

        # Debug controls for 3D movement
        if JulGame.IS_DEBUG
            moveSpeed = 1.0 * deltaTime
            if JulGame.InputModule.get_button_held_down("Right")
                this.parent.transform.position = Math.Vector3f(this.parent.transform.position.x + moveSpeed, this.parent.transform.position.y, this.parent.transform.position.z)
            elseif JulGame.InputModule.get_button_held_down("Left")
                this.parent.transform.position = Math.Vector3f(this.parent.transform.position.x - moveSpeed, this.parent.transform.position.y, this.parent.transform.position.z)
            end

            if !JulGame.InputModule.get_button_held_down("LCtrl")
                if JulGame.InputModule.get_button_held_down("Down")
                    this.parent.transform.position = Math.Vector3f(this.parent.transform.position.x, this.parent.transform.position.y + moveSpeed, this.parent.transform.position.z)
                elseif JulGame.InputModule.get_button_held_down("Up")
                    this.parent.transform.position = Math.Vector3f(this.parent.transform.position.x, this.parent.transform.position.y - moveSpeed, this.parent.transform.position.z)
                end
            end

            # Z-axis movement with Ctrl + Up/Down
            if JulGame.InputModule.get_button_held_down("LCtrl") && JulGame.InputModule.get_button_held_down("Up")
                this.parent.transform.position = Math.Vector3f(this.parent.transform.position.x, this.parent.transform.position.y, this.parent.transform.position.z + moveSpeed)
            elseif JulGame.InputModule.get_button_held_down("LCtrl") && JulGame.InputModule.get_button_held_down("Down")
                this.parent.transform.position = Math.Vector3f(this.parent.transform.position.x, this.parent.transform.position.y, this.parent.transform.position.z - moveSpeed)
            end

            # Rotation controls with Q/E
            if JulGame.InputModule.get_button_held_down("Q")
                this.parent.transform.rotation = Math.Vector3f(this.parent.transform.rotation.x, this.parent.transform.rotation.y, this.parent.transform.rotation.z + 90.0 * deltaTime)
            elseif JulGame.InputModule.get_button_held_down("E")
                this.parent.transform.rotation = Math.Vector3f(this.parent.transform.rotation.x, this.parent.transform.rotation.y, this.parent.transform.rotation.z - 90.0 * deltaTime)
            end

            # Look at cube with spacebar
            if JulGame.InputModule.get_button_pressed("2")

                camera = JulGame.MAIN.scene.camera
                println("trying to point at")
                if camera !== nothing
                    println("point at")
                    # Calculate direction to cube
                    cubePos = this.parent.transform.position
                    cameraPos = vec3d(camera.position.x, camera.position.y, camera.zPosition)
                    direction = MatrixOps.vector_sub(vec3d(cubePos.x, cubePos.y, cubePos.z), cameraPos)
                    direction = MatrixOps.vector_normalize(direction)

                    # Calculate yaw and pitch from direction
                    yaw = atan(direction.x, direction.z)
                    pitch = asin(direction.y)

                    # Convert to degrees and set camera rotation
                    camera.yaw = yaw * 180.0 / π
                    camera.pitch = pitch * 180.0 / π
                end
            end
        end
    end

    function Component.render(this::Mesh3D, main)
        Component.update(this, 0.167)
        # Clear triangles to raster
        empty!(this.vecTrianglesToRaster)

        # Get world matrix from entity transform
        pos = this.parent.transform.position
        scale = this.parent.transform.scale
        rot = this.parent.transform.rotation

        # Create world matrix
        matTrans = MatrixOps.matrix_make_translation(pos.x, pos.y, pos.z)
        matScale = MatrixOps.matrix_make_scale(scale.x, scale.y, 1.0)
        matRotZ = MatrixOps.matrix_make_rotation_z(rot.z)
        this.matWorld = MatrixOps.matrix_multiply_matrix(matRotZ, matScale)
        this.matWorld = MatrixOps.matrix_multiply_matrix(this.matWorld, matTrans)

        # Get camera position and create view matrix
        cameraPos = vec3d(main.scene.camera.position.x, main.scene.camera.position.y, main.scene.camera.zPosition)
        vUp = vec3d(0, 1, 0)
        vTarget = vec3d(0, 0, 1)

        # Create rotation matrices for camera
        matCameraRotY = MatrixOps.matrix_make_rotation_y(main.scene.camera.yaw)
        matCameraRotX = MatrixOps.matrix_make_rotation_x(main.scene.camera.pitch)

        # Apply rotations to target
        vTarget = MatrixOps.matrix_multiply_vector(matCameraRotY, vTarget)
        vTarget = MatrixOps.matrix_multiply_vector(matCameraRotX, vTarget)

        # Create camera matrix
        matCamera = MatrixOps.matrix_point_at(cameraPos, vTarget, vUp)
        matView = MatrixOps.matrix_quick_inverse(matCamera)

        # Process each triangle
        for tri in this.mesh.tris
            triProjected::triangle = triangle()
			triTransformed::triangle = triangle()
			triViewed::Ref{triangle} = Ref(triangle())

            # Transform triangle vertices
            triTransformed.p[1] = MatrixOps.matrix_multiply_vector(this.matWorld, tri.p[1])
            triTransformed.p[2] = MatrixOps.matrix_multiply_vector(this.matWorld, tri.p[2])
            triTransformed.p[3] = MatrixOps.matrix_multiply_vector(this.matWorld, tri.p[3])

            # Debug check for NaNs after world transform
            if any(isnan.(triTransformed.p[1].x) .|| isnan.(triTransformed.p[1].y) .|| isnan.(triTransformed.p[1].z))
                println("NaN detected after world transform")
                println("Position: ", pos)
                println("Scale: ", scale)
                println("Rotation: ", rot)
            end

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
            vCameraRay::vec3d = MatrixOps.vector_sub(triTransformed.p[1], cameraPos)
            if MatrixOps.vector_dot_product(normal, vCameraRay) < 0.0
                # Combine camera-based lighting with fixed light direction
                camera_light = MatrixOps.vector_normalize(vCameraRay)
                fixed_light = MatrixOps.vector_normalize(vec3d(-0.707, -0.707, -1.0))
                
                # Calculate dot products for both light sources
                dp_camera = MatrixOps.vector_dot_product(normal, camera_light)
                dp_fixed = MatrixOps.vector_dot_product(normal, fixed_light)
                
                # Combine the lighting (weighted average)
                dp = 0.3 * dp_camera + 0.7 * dp_fixed

                # Add some ambient light to prevent completely dark faces
                ambient = 0.2
                dp = max(ambient, dp)

                # Convert to view space
                triViewed[].p[1] = MatrixOps.matrix_multiply_vector(matView, triTransformed.p[1])
                triViewed[].p[2] = MatrixOps.matrix_multiply_vector(matView, triTransformed.p[2])
                triViewed[].p[3] = MatrixOps.matrix_multiply_vector(matView, triTransformed.p[3])

                # Debug check for NaNs after view transform
                if any(isnan.(triViewed[].p[1].x) .|| isnan.(triViewed[].p[1].y) .|| isnan.(triViewed[].p[1].z))
                    println("NaN detected after view transform")
                    println("Camera position: ", cameraPos)
                    println("Camera yaw: ", main.scene.camera.yaw)
                    println("Camera pitch: ", main.scene.camera.pitch)
                end

                # Clip against near plane
                clipped = Ref([triangle([vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0)]), triangle([vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0)])])
                nClippedTriangles = triangle_clip_against_plane(vec3d(0.0, 0.0, this.fNear), vec3d(0.0, 0.0, 1.0), triViewed, clipped)

                if nClippedTriangles > 0
                    for i in 1:nClippedTriangles
                        # Project triangles
                        triProjected.p[1] = MatrixOps.matrix_multiply_vector(this.matProj, clipped[][i].p[1])
                        triProjected.p[2] = MatrixOps.matrix_multiply_vector(this.matProj, clipped[][i].p[2])
                        triProjected.p[3] = MatrixOps.matrix_multiply_vector(this.matProj, clipped[][i].p[3])

                        # Debug check for NaNs after projection
                        if any(isnan.(triProjected.p[1].x) .|| isnan.(triProjected.p[1].y) .|| isnan.(triProjected.p[1].z))
                            println("NaN detected after projection")
                            println("Near plane: ", this.fNear)
                            println("Far plane: ", this.fFar)
                            println("FOV: ", this.fFov)
                        end

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
                    test::Ref{triangle} = Ref(listTriangles[begin])
                    popfirst!(listTriangles)
                    nNewTriangles -= 1

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

            # Draw triangles
            for tri in listTriangles
                # Get material for the triangle
                material = get(this.mesh.materials, this.mesh.currentMaterial, Material())
                
                # Apply texture coordinates based on texture mode if texture exists
                tex_coords = copy(tri.texCoords)
                
                # Get the diffuse texture (or any available texture) for rendering
                texture = nothing
                if haskey(material.textures, TEXTURE_TYPE_DIFFUSE)
                    texture = material.textures[TEXTURE_TYPE_DIFFUSE]
                elseif !isempty(material.textures)
                    texture = first(material.textures)[2]
                end

                if texture !== nothing
                    tex_coords = [apply_texture_mode(coord, texture) for coord in tex_coords]
                end

                sdl_verts = [
                    SDL_Vertex(SDL_FPoint(tri.p[1].x, tri.p[1].y), tri.color, SDL_FPoint(tex_coords[1].x, tex_coords[1].y)),
                    SDL_Vertex(SDL_FPoint(tri.p[2].x, tri.p[2].y), tri.color, SDL_FPoint(tex_coords[2].x, tex_coords[2].y)),
                    SDL_Vertex(SDL_FPoint(tri.p[3].x, tri.p[3].y), tri.color, SDL_FPoint(tex_coords[3].x, tex_coords[3].y))
                ]

                # Use material texture if available, otherwise use color
                texture_ptr = texture !== nothing ? texture.texture : C_NULL
                SDL_RenderGeometry(JulGame.Renderer, texture_ptr, sdl_verts, length(sdl_verts), C_NULL, 0)
                
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

    function avg_z(t::triangle)
        z_vals = [p.z for p in t.p]
        return sum(z_vals) / length(z_vals)
    end

    function triangle_clip_against_plane(plane_p::vec3d, plane_n::vec3d, in_tri::Ref{triangle}, out_tris::Ref{Vector{triangle}})::Int
        # Make sure plane normal is indeed normal 
        plane_n = MatrixOps.vector_normalize(plane_n)

        dist = (p::vec3d) -> begin
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
            
            out_tris[][1].p[1] = inside_points[1]
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

        return 0  # Default return if no other case matches
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