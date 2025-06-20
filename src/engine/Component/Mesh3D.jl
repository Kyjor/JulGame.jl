module Mesh3DModule
    using ..JulGame
    using ..JulGame.Math
    using ..JulGame.SDL2
    using ..JulGame.SDL2.LibSDL2
    using ..JulGame.Component
    using ..JulGame.InputModule
    

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
        material::String
        function triangle(p = [vec3d(0,0,0), vec3d(0,0,0), vec3d(0,0,0)], sym = nothing, color = nothing, texCoords = [vec3d(0,0,0), vec3d(0,0,0), vec3d(0,0,0)], material = "default")
            new(p, sym, color, texCoords, material)
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

    # Texture compression formats
    const TEXTURE_COMPRESSION_NONE = 0
    const TEXTURE_COMPRESSION_DXT1 = 1
    const TEXTURE_COMPRESSION_DXT3 = 2
    const TEXTURE_COMPRESSION_DXT5 = 3
    const TEXTURE_COMPRESSION_ETC2 = 4

    mutable struct Texture
        surface::Ptr{SDL_Surface}
        texture::Ptr{SDL_Texture}
        width::Int
        height::Int
        mode::Int
        filter::Int
        type::Int
        compression::Int
        compressed_data::Vector{UInt8}
        original_size::Int

        function Texture(surface::Ptr{SDL_Surface}, mode::Int = TEXTURE_MODE_REPEAT, 
                        filter::Int = TEXTURE_FILTER_LINEAR, type::Int = TEXTURE_TYPE_DIFFUSE,
                        compression::Int = TEXTURE_COMPRESSION_NONE)
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
            
            w = Ref{Int32}(0)
            h = Ref{Int32}(0)
            SDL_QueryTexture(texture, C_NULL, C_NULL, w, h)

            width = w[]
            height = h[]
            new(surface, texture, width, height, mode, filter, type, compression, UInt8[], 0)
        end
    end

    function compress_texture(texture::Texture, format::Int = TEXTURE_COMPRESSION_DXT1)::Bool
        if texture.compression != TEXTURE_COMPRESSION_NONE
            return false  # Already compressed
        end

        # Get surface data
        surface = texture.surface
        if surface == C_NULL
            return false
        end

        # Calculate original size
        texture.original_size = surface.w * surface.h * 4  # RGBA

        # Compress based on format
        if format == TEXTURE_COMPRESSION_DXT1
            # DXT1 compression (8:1 ratio for RGB)
            compressed_size = div(texture.original_size, 8)
            texture.compressed_data = Vector{UInt8}(undef, compressed_size)
            # TODO: Implement actual DXT1 compression
        elseif format == TEXTURE_COMPRESSION_DXT3
            # DXT3 compression (4:1 ratio for RGBA)
            compressed_size = div(texture.original_size, 4)
            texture.compressed_data = Vector{UInt8}(undef, compressed_size)
            # TODO: Implement actual DXT3 compression
        elseif format == TEXTURE_COMPRESSION_DXT5
            # DXT5 compression (4:1 ratio for RGBA)
            compressed_size = div(texture.original_size, 4)
            texture.compressed_data = Vector{UInt8}(undef, compressed_size)
            # TODO: Implement actual DXT5 compression
        elseif format == TEXTURE_COMPRESSION_ETC2
            # ETC2 compression (6:1 ratio for RGB)
            compressed_size = div(texture.original_size, 6)
            texture.compressed_data = Vector{UInt8}(undef, compressed_size)
            # TODO: Implement actual ETC2 compression
        else
            return false
        end

        texture.compression = format
        return true
    end

    function decompress_texture(texture::Texture)::Bool
        if texture.compression == TEXTURE_COMPRESSION_NONE
            return false  # Not compressed
        end

        # Decompress based on format
        if texture.compression == TEXTURE_COMPRESSION_DXT1
            # TODO: Implement DXT1 decompression
            pass
        elseif texture.compression == TEXTURE_COMPRESSION_DXT3
            # TODO: Implement DXT3 decompression
            pass
        elseif texture.compression == TEXTURE_COMPRESSION_DXT5
            # TODO: Implement DXT5 decompression
            pass
        elseif texture.compression == TEXTURE_COMPRESSION_ETC2
            # TODO: Implement ETC2 decompression
            pass
        end

        # Clear compressed data
        empty!(texture.compressed_data)
        texture.compression = TEXTURE_COMPRESSION_NONE
        return true
    end

    function load_texture(file_path::String; 
                         mode::Int = TEXTURE_MODE_REPEAT,
                         filter::Int = TEXTURE_FILTER_LINEAR,
                         type::Int = TEXTURE_TYPE_DIFFUSE,
                         compression::Int = TEXTURE_COMPRESSION_NONE)::Texture
        println("Loading texture from: $file_path")
        # Get file extension
        ext = lowercase(splitext(file_path)[2])
        
        # Load texture based on format
        surface = if ext == ".bmp"
            IMG_Load(file_path)
        elseif ext == ".png"
            IMG_Load(file_path)
        elseif ext == ".jpg" || ext == ".jpeg"
            IMG_Load(file_path)
        elseif ext == ".dds"  # DirectDraw Surface (compressed texture)
            IMG_Load(file_path)
        else
            error("Unsupported texture format: $ext")
        end

        if surface == C_NULL
            error("Failed to load texture: $file_path")
        end

        println("Surface loaded successfully")
        texture = Texture(surface, mode, filter, type, compression)
        
        # Apply compression if requested
        if compression != TEXTURE_COMPRESSION_NONE
            compress_texture(texture, compression)
        end

        return texture
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

    include("../3D/FastObj.jl")
    using .FastObj
    
    export Mesh3D

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
            this.mesh = mesh(nothing)
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
        try
            # Use the FastObj parser to load the mesh data
            vertices, normals, texcoords, faces, face_texcoords, face_normals, materials = FastObj.parse_obj_file(file_path)
            println("Parsed OBJ file successfully")
            println("Vertices: $(length(vertices))")
            println("Normals: $(length(normals))")
            println("Texcoords: $(length(texcoords))")
            println("Faces: $(length(faces))")
            
            # Clear existing data
            empty!(this.mesh.tris)
            this.mesh.materials = materials
            
            # Create triangles from the parsed data
            for (i, face) in enumerate(faces)
                println("Processing face $i with $(length(face)) vertices")
                println("Face vertices: $face")
                
                if length(face) >= 3
                    # For quads, create two triangles
                    if length(face) == 4
                        println("Creating two triangles from quad face")
                        # First triangle
                        tri1 = triangle([
                            vertices[face[1]],
                            vertices[face[2]],
                            vertices[face[3]]
                        ])
                        
                        # Add texture coordinates if available
                        if i <= length(face_texcoords) && !isempty(face_texcoords[i])
                            println("Adding texture coordinates to first triangle")
                            tri1.texCoords = [
                                texcoords[face_texcoords[i][1]],
                                texcoords[face_texcoords[i][2]],
                                texcoords[face_texcoords[i][3]]
                            ]
                        end
                        
                        # Set the material for this triangle
                        tri1.material = this.mesh.currentMaterial
                        push!(this.mesh.tris, tri1)
                        println("Added first triangle to mesh")
                        
                        # Second triangle
                        tri2 = triangle([
                            vertices[face[1]],
                            vertices[face[3]],
                            vertices[face[4]]
                        ])
                        
                        # Add texture coordinates if available
                        if i <= length(face_texcoords) && !isempty(face_texcoords[i])
                            println("Adding texture coordinates to second triangle")
                            tri2.texCoords = [
                                texcoords[face_texcoords[i][1]],
                                texcoords[face_texcoords[i][3]],
                                texcoords[face_texcoords[i][4]]
                            ]
                        end
                        
                        # Set the material for this triangle
                        tri2.material = this.mesh.currentMaterial
                        push!(this.mesh.tris, tri2)
                        println("Added second triangle to mesh")
                    else
                        println("Creating single triangle from face")
                        # For triangles, create a single triangle
                        tri = triangle([
                            vertices[face[1]],
                            vertices[face[2]],
                            vertices[face[3]]
                        ])
                        
                        # Add texture coordinates if available
                        if i <= length(face_texcoords) && !isempty(face_texcoords[i])
                            println("Adding texture coordinates to triangle")
                            tri.texCoords = [
                                texcoords[face_texcoords[i][1]],
                                texcoords[face_texcoords[i][2]],
                                texcoords[face_texcoords[i][3]]
                            ]
                        end
                        
                        # Set the material for this triangle
                        tri.material = this.mesh.currentMaterial
                        push!(this.mesh.tris, tri)
                        println("Added triangle to mesh")
                    end
                else
                    println("Skipping face with less than 3 vertices")
                end
            end
            
            println("Created $(length(this.mesh.tris)) triangles")
            println("Current material: $(this.mesh.currentMaterial)")
            return true
        catch e
            @error "Failed to load OBJ file: $file_path" exception=(e, catch_backtrace())
            return false
        end
    end

    function load_material_library(this::Mesh3D, mtl_path::String)
        if !isfile(mtl_path)
            @warn "Material library file not found: $mtl_path"
            return
        end

        f = open(mtl_path, "r")
        current_material = nothing

        while !eof(f)
            line = readline(f)
            s = split(line)
            
            if isempty(s)
                continue
            end

            if s[1] == "newmtl"
                println("newmtl: ", s[2])
                current_material = Material(string(s[2]))
                this.mesh.materials[s[2]] = current_material
            elseif s[1] == "map_Kd" && current_material !== nothing
                # Load texture
                texture_path = joinpath(dirname(mtl_path), s[2])
                if isfile(texture_path)
                    texture = load_texture(texture_path)
                    current_material.textures[TEXTURE_TYPE_DIFFUSE] = texture
                else
                    @warn "Texture file not found: $texture_path"
                end
            end
        end

        close(f)
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
        
        if length(this.mesh.tris) == 0
            println("creating cube")
            this.mesh = create_cube()
        end

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
                    cameraPos = vec3d(camera.position.x, camera.position.y, camera.position.z)
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
        # Clear triangles to raster
        empty!(this.vecTrianglesToRaster)

        # Get world matrix from entity transform
        pos = this.parent.transform.position
        scale = this.parent.transform.scale
        rot = this.parent.transform.rotation

        # Create world matrix (correct order: Scale -> Rotation -> Translation)
        matScale = MatrixOps.matrix_make_scale(scale.x, scale.y, scale.z)
        matRotX = MatrixOps.matrix_make_rotation_x(rot.x * π / 180.0)  # Convert to radians
        matRotY = MatrixOps.matrix_make_rotation_y(rot.y * π / 180.0)
        matRotZ = MatrixOps.matrix_make_rotation_z(rot.z * π / 180.0)
        matTrans = MatrixOps.matrix_make_translation(pos.x, pos.y, pos.z)
        
        # Combine matrices in correct order
        this.matWorld = MatrixOps.matrix_multiply_matrix(matScale, matRotX)
        this.matWorld = MatrixOps.matrix_multiply_matrix(this.matWorld, matRotY)
        this.matWorld = MatrixOps.matrix_multiply_matrix(this.matWorld, matRotZ)
        this.matWorld = MatrixOps.matrix_multiply_matrix(this.matWorld, matTrans)

        # Get camera position and create view matrix
        cameraPos = vec3d(main.scene.camera.position.x, main.scene.camera.position.y, main.scene.camera.position.z)
        vUp = vec3d(0, 1, 0)
        vForward = vec3d(0, 0, 1)

        # Create rotation matrices for camera (convert degrees to radians)
        matCameraRotY = MatrixOps.matrix_make_rotation_y(main.scene.camera.yaw * π / 180.0)
        matCameraRotX = MatrixOps.matrix_make_rotation_x(main.scene.camera.pitch * π / 180.0)

        # Apply rotations to forward vector
        vForward = MatrixOps.matrix_multiply_vector(matCameraRotY, vForward)
        vForward = MatrixOps.matrix_multiply_vector(matCameraRotX, vForward)
        
        # Calculate target position (not direction)
        vTarget = MatrixOps.vector_add(cameraPos, vForward)

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

            # Calculate normal
            normal::vec3d = vec3d(0, 0, 0)
            line1::vec3d = vec3d(0, 0, 0)
            line2::vec3d = vec3d(0, 0, 0)

            # Get lines either side of the triangle
            line1 = MatrixOps.vector_sub(triTransformed.p[2], triTransformed.p[1])
            line2 = MatrixOps.vector_sub(triTransformed.p[3], triTransformed.p[1])
            
            # Take cross product of lines to get normal to triangle surface 
            normal = MatrixOps.vector_cross_product(line1, line2)
            normal = MatrixOps.vector_normalize(normal)

            # Calculate distance from camera to triangle center
            triCenter = MatrixOps.vector_div(
                MatrixOps.vector_add(
                    MatrixOps.vector_add(triTransformed.p[1], triTransformed.p[2]),
                    triTransformed.p[3]
                ),
                3.0
            )
            distanceToCamera = MatrixOps.vector_length(
                MatrixOps.vector_sub(cameraPos, triCenter)
            )

            # Skip triangles that are too far away
            if distanceToCamera > this.fFar
                continue
            end

            # Get Ray from triangle to camera 
            vCameraRay::vec3d = MatrixOps.vector_sub(cameraPos, triTransformed.p[1])
            if MatrixOps.vector_dot_product(normal, vCameraRay) > 0.0
                # Convert to view space
                triViewed[].p[1] = MatrixOps.matrix_multiply_vector(matView, triTransformed.p[1])
                triViewed[].p[2] = MatrixOps.matrix_multiply_vector(matView, triTransformed.p[2])
                triViewed[].p[3] = MatrixOps.matrix_multiply_vector(matView, triTransformed.p[3])

                # Clip against near plane
                clipped = Ref([triangle([vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0)]), triangle([vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0)])])
                nClippedTriangles = triangle_clip_against_plane(vec3d(0.0, 0.0, this.fNear), vec3d(0.0, 0.0, 1.0), triViewed, clipped)

                if nClippedTriangles > 0
                    for i in 1:nClippedTriangles
                        # Project triangles
                        triProjected.p[1] = MatrixOps.matrix_multiply_vector(this.matProj, clipped[][i].p[1])
                        triProjected.p[2] = MatrixOps.matrix_multiply_vector(this.matProj, clipped[][i].p[2])
                        triProjected.p[3] = MatrixOps.matrix_multiply_vector(this.matProj, clipped[][i].p[3])

                        # Store the view-space z values for depth testing BEFORE perspective divide
                        viewZ1 = clipped[][i].p[1].z
                        viewZ2 = clipped[][i].p[2].z
                        viewZ3 = clipped[][i].p[3].z

                        # Scale into view (perspective divide)
                        triProjected.p[1] = MatrixOps.vector_div(triProjected.p[1], triProjected.p[1].w)
                        triProjected.p[2] = MatrixOps.vector_div(triProjected.p[2], triProjected.p[2].w)
                        triProjected.p[3] = MatrixOps.vector_div(triProjected.p[3], triProjected.p[3].w)

                        # Use view-space Z for depth sorting
                        triProjected.p[1].z = viewZ1
                        triProjected.p[2].z = viewZ2
                        triProjected.p[3].z = viewZ3

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

                        # Calculate lighting
                        light_direction = vec3d(0.0, 0.0, -1.0)
                        dp = MatrixOps.vector_dot_product(normal, light_direction)
                        dp = max(0.1, dp)  # Add some ambient light

                        # Set color based on lighting
                        r = round(Int, 255 * dp)
                        g = round(Int, 255 * dp)
                        b = round(Int, 255 * dp)
                        triProjected.color = SDL_Color(r, g, b, 255)

                        push!(this.vecTrianglesToRaster, triProjected)
                    end
                end
            end
        end

        # Sort triangles by average z depth (back to front)
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
                    println("Using diffuse texture")
                elseif !isempty(material.textures)
                    texture = first(material.textures)[2]
                    println("Using fallback texture")
                end

                if texture !== nothing
                    tex_coords = [apply_texture_mode(coord, texture) for coord in tex_coords]
                    #println("Texture coordinates applied: ", tex_coords)
                end

                sdl_verts = [
                    SDL_Vertex(SDL_FPoint(tri.p[1].x, tri.p[1].y), tri.color, SDL_FPoint(tex_coords[1].x, tex_coords[1].y)),
                    SDL_Vertex(SDL_FPoint(tri.p[2].x, tri.p[2].y), tri.color, SDL_FPoint(tex_coords[2].x, tex_coords[2].y)),
                    SDL_Vertex(SDL_FPoint(tri.p[3].x, tri.p[3].y), tri.color, SDL_FPoint(tex_coords[3].x, tex_coords[3].y))
                ]

                # Use material texture if available, otherwise use color
                texture_ptr = texture !== nothing ? texture.texture : C_NULL
                if texture_ptr != C_NULL
                    #println("Rendering with texture")
                else
                    #println("Rendering without texture")
                end

                # Set the blend mode for proper texture rendering
                SDL_SetRenderDrawBlendMode(JulGame.Renderer, SDL_BLENDMODE_BLEND)
                
                # Render the geometry
                result = SDL_RenderGeometry(JulGame.Renderer, texture_ptr, sdl_verts, length(sdl_verts), C_NULL, 0)
                if result < 0
                    println("SDL_RenderGeometry failed: ", unsafe_string(SDL_GetError()))
                end
                
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
            triangle([ vec3d(0.0, 0.0, 0.0), vec3d(0.0, 1.0, 0.0), vec3d(1.0, 1.0, 0.0)], 
                    nothing, nothing, [vec3d(0.0, 0.0, 0.0), vec3d(0.0, 1.0, 0.0), vec3d(1.0, 1.0, 0.0)]),
            triangle([ vec3d(0.0, 0.0, 0.0), vec3d(1.0, 1.0, 0.0), vec3d(1.0, 0.0, 0.0)],
                    nothing, nothing, [vec3d(0.0, 0.0, 0.0), vec3d(1.0, 1.0, 0.0), vec3d(1.0, 0.0, 0.0)]),
            # EAST
            triangle([ vec3d(1.0, 0.0, 0.0), vec3d(1.0, 1.0, 0.0), vec3d(1.0, 1.0, 1.0)],
                    nothing, nothing, [vec3d(0.0, 0.0, 0.0), vec3d(0.0, 1.0, 0.0), vec3d(0.0, 1.0, 1.0)]),
            triangle([ vec3d(1.0, 0.0, 0.0), vec3d(1.0, 1.0, 1.0), vec3d(1.0, 0.0, 1.0)],
                    nothing, nothing, [vec3d(0.0, 0.0, 0.0), vec3d(0.0, 1.0, 1.0), vec3d(0.0, 0.0, 1.0)]),
            # NORTH
            triangle([ vec3d(1.0, 0.0, 1.0), vec3d(1.0, 1.0, 1.0), vec3d(0.0, 1.0, 1.0)],
                    nothing, nothing, [vec3d(1.0, 0.0, 0.0), vec3d(1.0, 1.0, 0.0), vec3d(0.0, 1.0, 0.0)]),
            triangle([ vec3d(1.0, 0.0, 1.0), vec3d(0.0, 1.0, 1.0), vec3d(0.0, 0.0, 1.0)],
                    nothing, nothing, [vec3d(1.0, 0.0, 0.0), vec3d(0.0, 1.0, 0.0), vec3d(0.0, 0.0, 0.0)]),
            # WEST
            triangle([ vec3d(0.0, 0.0, 1.0), vec3d(0.0, 1.0, 1.0), vec3d(0.0, 1.0, 0.0)],
                    nothing, nothing, [vec3d(1.0, 0.0, 0.0), vec3d(1.0, 1.0, 0.0), vec3d(1.0, 1.0, 1.0)]),
            triangle([ vec3d(0.0, 0.0, 1.0), vec3d(0.0, 1.0, 0.0), vec3d(0.0, 0.0, 0.0)],
                    nothing, nothing, [vec3d(1.0, 0.0, 0.0), vec3d(1.0, 1.0, 1.0), vec3d(1.0, 0.0, 1.0)]),
            # TOP
            triangle([ vec3d(0.0, 1.0, 0.0), vec3d(0.0, 1.0, 1.0), vec3d(1.0, 1.0, 1.0)],
                    nothing, nothing, [vec3d(0.0, 0.0, 0.0), vec3d(0.0, 1.0, 0.0), vec3d(1.0, 1.0, 0.0)]),
            triangle([ vec3d(0.0, 1.0, 0.0), vec3d(1.0, 1.0, 1.0), vec3d(1.0, 1.0, 0.0)],
                    nothing, nothing, [vec3d(0.0, 0.0, 0.0), vec3d(1.0, 1.0, 0.0), vec3d(1.0, 0.0, 0.0)]),
            # BOTTOM
            triangle([ vec3d(1.0, 0.0, 1.0), vec3d(0.0, 0.0, 1.0), vec3d(0.0, 0.0, 0.0)],
                    nothing, nothing, [vec3d(1.0, 0.0, 0.0), vec3d(0.0, 0.0, 0.0), vec3d(0.0, 0.0, 1.0)]),
            triangle([ vec3d(1.0, 0.0, 1.0), vec3d(0.0, 0.0, 0.0), vec3d(1.0, 0.0, 0.0)],
                    nothing, nothing, [vec3d(1.0, 0.0, 0.0), vec3d(0.0, 0.0, 1.0), vec3d(1.0, 0.0, 1.0)]),
        ])
        
        # Set material for all triangles
        for tri in meshCube.tris
            tri.material = "default"
        end
        
        return meshCube
    end

    function create_plane()
        meshPlane = mesh(triangle[
            triangle([ vec3d(0.0, 0.0, 0.0), vec3d(0.0, 1.0, 0.0), vec3d(1.0, 1.0, 0.0)],
                    nothing, nothing, [vec3d(0.0, 0.0, 0.0), vec3d(0.0, 1.0, 0.0), vec3d(1.0, 1.0, 0.0)]),
            triangle([ vec3d(0.0, 0.0, 0.0), vec3d(1.0, 1.0, 0.0), vec3d(1.0, 0.0, 0.0)],
                    nothing, nothing, [vec3d(0.0, 0.0, 0.0), vec3d(1.0, 1.0, 0.0), vec3d(1.0, 0.0, 0.0)]),
        ])
        
        return meshPlane
    end
end 