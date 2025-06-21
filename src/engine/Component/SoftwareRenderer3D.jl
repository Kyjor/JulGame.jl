module SoftwareRenderer3DModule
    using ..JulGame
    using ..JulGame.Math
    using ..JulGame.SDL2
    using ..JulGame.SDL2.LibSDL2
    using ..JulGame.Component
    using ..JulGame.InputModule
    
    # Import MeshIO and FileIO for 3D file loading
    using FileIO, MeshIO
    using GeometryBasics
    global MESHIO_AVAILABLE = true
    
    # Import our 3D modules
    include("Math3D.jl")
    include("Geometry3D.jl") 
    include("Materials3D.jl")
    include("MeshLoader3D.jl")
    include("MeshLoaderIntegration.jl")
    
    using .Math3DModule
    using .Geometry3DModule
    using .Materials3DModule
    using .MeshLoader3DModule
    using .MeshLoaderIntegrationModule

    export SoftwareRenderer3D, Vec3D, Mat4x4, Triangle3D, Vertex3D, RenderBox, RenderMesh, load_mesh_from_file!

    # Re-export from modules
    using .Math3DModule: dot, cross, length_of, normalize, min_pairwise, max_pairwise, 
                        translation_matrix, scaling_matrix, x_rotation_matrix, y_rotation_matrix, 
                        z_rotation_matrix, rotation_matrix, viewport_matrix, perspective_matrix, 
                        perspective_divide!
    using .MeshLoader3DModule: parse_obj_file, parse_mtl_file, parse_obj_materials, load_texture_average_color

    # Main Software Renderer component
    mutable struct SoftwareRenderer3D
        parent
        layer::Int
        isWorldEntity::Bool
        
        # Rendering properties
        triangles::Vector{Triangle3D}
        state::RenderState
        state_stack::Vector{RenderState}
        boxes::Vector{RenderBox}
        meshes::Vector{RenderMesh}
        
        # Texture cache
        texture_cache::Dict{String, Ptr{SDL_Texture}}
        
        # Perspective correction settings
        enable_perspective_subdivision::Bool
        subdivision_threshold_area::Float64
        subdivision_threshold_z_ratio::Float64
        max_subdivision_depth::Int
        
        # Camera properties
        camera_position::Vec3D
        camera_rotation::Vec3D
        camera_zoom::Vec3D
        perspective_enabled::Bool
        reverse_sort_triangles::Bool
        
        # Projection properties
        fov::Float64
        aspect_ratio::Float64
        near::Float64
        far::Float64
        light_direction::Vec3D

        function SoftwareRenderer3D()
            this = new()
            this.parent = C_NULL
            this.layer = 0
            this.isWorldEntity = true
            
            this.triangles = Triangle3D[]
            this.state = RenderState()
            this.state_stack = RenderState[]
            this.boxes = RenderBox[]
            this.meshes = RenderMesh[]
            this.texture_cache = Dict{String, Ptr{SDL_Texture}}()
            
            # Initialize perspective correction settings
            this.enable_perspective_subdivision = true
            this.subdivision_threshold_area = 10000.0  # Pixels
            this.subdivision_threshold_z_ratio = 1.5   # Z depth variation ratio
            this.max_subdivision_depth = 3            # Maximum recursion depth
            
            this.camera_position = Vec3D(0, 0, 0)
            this.camera_rotation = Vec3D(0, 0, 0)
            this.camera_zoom = Vec3D(1, 1, 1)
            this.perspective_enabled = true
            this.reverse_sort_triangles = false
            
            this.fov = π / 3.0  # 60 degrees
            this.aspect_ratio = 1.0
            this.near = 1.0 / 1024.0
            this.far = 1024.0
            this.light_direction = normalize(Vec3D(0.0, 0.5, -1.0, 0.0))
            
            return this
        end
    end



    # Calculate perspective-correct UV coordinates using subdivision
    function calculate_perspective_correct_uv(u::Float64, v::Float64, z::Float64)::Tuple{Float64, Float64}
        # For now, return original coordinates - subdivision will handle perspective correction
        return (u, v)
    end

    # Subdivide triangle for better perspective-correct texture mapping approximation
    function subdivide_triangle_for_perspective(renderer::SoftwareRenderer3D, color::SDL_Color,
                                              a::Vec3D, b::Vec3D, c::Vec3D,
                                              u1::Float64, v1::Float64,
                                              u2::Float64, v2::Float64,
                                              u3::Float64, v3::Float64,
                                              texture::Ptr{SDL_Texture},
                                              depth::Int = 0)::AABB
        
        # Check if subdivision is enabled
        if !renderer.enable_perspective_subdivision
            return add_triangle_direct!(renderer, color, a, b, c, u1, v1, u2, v2, u3, v3, texture)
        end
        
        # Calculate triangle size in screen space to determine if subdivision is needed
        screen_area = abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y))
        
        # Calculate depth variation to determine if perspective correction is needed
        z_min = min(a.z, b.z, c.z)
        z_max = max(a.z, b.z, c.z)
        z_ratio = z_max / max(z_min, 0.001)  # Avoid division by zero
        
        # Subdivide if:
        # 1. Triangle is large in screen space (configurable threshold)
        # 2. There's significant depth variation (configurable ratio)
        # 3. We haven't reached maximum subdivision depth (configurable)
        should_subdivide = (screen_area > renderer.subdivision_threshold_area || 
                           z_ratio > renderer.subdivision_threshold_z_ratio) && 
                          depth < renderer.max_subdivision_depth
        
        if !should_subdivide
            # Base case: add the triangle without further subdivision
            return add_triangle_direct!(renderer, color, a, b, c, u1, v1, u2, v2, u3, v3, texture)
        end
        
        # Subdivide triangle into 4 smaller triangles
        # Calculate midpoints
        mid_ab = Vec3D((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2, 1.0)
        mid_bc = Vec3D((b.x + c.x) / 2, (b.y + c.y) / 2, (b.z + c.z) / 2, 1.0)
        mid_ca = Vec3D((c.x + a.x) / 2, (c.y + a.y) / 2, (c.z + a.z) / 2, 1.0)
        
        # Calculate midpoint UV coordinates
        u_ab, v_ab = (u1 + u2) / 2, (v1 + v2) / 2
        u_bc, v_bc = (u2 + u3) / 2, (v2 + v3) / 2
        u_ca, v_ca = (u3 + u1) / 2, (v3 + v1) / 2
        
        # Recursively subdivide the 4 triangles
        aabb1 = subdivide_triangle_for_perspective(renderer, color, a, mid_ab, mid_ca, u1, v1, u_ab, v_ab, u_ca, v_ca, texture, depth + 1)
        aabb2 = subdivide_triangle_for_perspective(renderer, color, mid_ab, b, mid_bc, u_ab, v_ab, u2, v2, u_bc, v_bc, texture, depth + 1)
        aabb3 = subdivide_triangle_for_perspective(renderer, color, mid_ca, mid_bc, c, u_ca, v_ca, u_bc, v_bc, u3, v3, texture, depth + 1)
        aabb4 = subdivide_triangle_for_perspective(renderer, color, mid_ab, mid_bc, mid_ca, u_ab, v_ab, u_bc, v_bc, u_ca, v_ca, texture, depth + 1)
        
        # Combine AABBs
        combined_min = min_pairwise(min_pairwise(aabb1.min, aabb2.min), min_pairwise(aabb3.min, aabb4.min))
        combined_max = max_pairwise(max_pairwise(aabb1.max, aabb2.max), max_pairwise(aabb3.max, aabb4.max))
        
        return AABB(combined_min, combined_max)
    end

    # Direct triangle addition without subdivision (internal function)
    function add_triangle_direct!(renderer::SoftwareRenderer3D, color::SDL_Color, 
                                 a::Vec3D, b::Vec3D, c::Vec3D,
                                 u1::Float64, v1::Float64,
                                 u2::Float64, v2::Float64,
                                 u3::Float64, v3::Float64,
                                 texture::Ptr{SDL_Texture})::AABB
        
        if color.a == 0
            return AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        end
        
        # Transform vertices
        ta = renderer.state.transform * a
        tb = renderer.state.transform * b
        tc = renderer.state.transform * c
        
        # Check if behind camera
        if ta.w <= 0 || tb.w <= 0 || tc.w <= 0
            return AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        end
        
        # Store Z values for depth
        z1, z2, z3 = ta.z, tb.z, tc.z
        
        # Perspective divide
        perspective_divide!(ta)
        perspective_divide!(tb)
        perspective_divide!(tc)
        
        # Frustum culling (basic)
        windowSize = JulGame.MAIN.windowManager.windowSize
        width = windowSize.x
        height = windowSize.y
        
        if (ta.x < 0 && tb.x < 0 && tc.x < 0) ||
           (ta.x > width && tb.x > width && tc.x > width) ||
           (ta.y < 0 && tb.y < 0 && tc.y < 0) ||
           (ta.y > height && tb.y > height && tc.y > height)
            return AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        end
        
        # Create triangle
        triangle = Triangle3D(
            Vertex3D(ta.x, ta.y, z1, color, u1, v1),
            Vertex3D(tb.x, tb.y, z2, color, u2, v2),
            Vertex3D(tc.x, tc.y, z3, color, u3, v3),
            texture
        )
        
        push!(renderer.triangles, triangle)
        
        return AABB(min_pairwise(ta, min_pairwise(tb, tc)), max_pairwise(ta, max_pairwise(tb, tc)))
    end

    # Add triangle to render queue with perspective-correct texture coordinates
    function add_triangle!(renderer::SoftwareRenderer3D, color::SDL_Color, 
                          a::Vec3D, b::Vec3D, c::Vec3D,
                          u1::Float64 = 0.0, v1::Float64 = 0.0,
                          u2::Float64 = 0.0, v2::Float64 = 0.0,
                          u3::Float64 = 0.0, v3::Float64 = 0.0,
                          texture::Ptr{SDL_Texture} = Ptr{SDL_Texture}(C_NULL))::AABB
        
        if color.a == 0
            return AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        end
        
        # Use subdivision for better perspective-correct texture mapping
        # This approximates perspective correction by subdividing large or depth-varying triangles
        return subdivide_triangle_for_perspective(renderer, color, a, b, c, u1, v1, u2, v2, u3, v3, texture, 0)
    end

    # Add rectangle
    function add_fill_rectangle!(renderer::SoftwareRenderer3D, a::Vec3D, b::Vec3D, c::Vec3D, d::Vec3D, texture::Ptr{SDL_Texture} = Ptr{SDL_Texture}(C_NULL))::AABB
        aabb1 = add_triangle!(renderer, renderer.state.fill_color, a, b, c, 0.0, 0.0, 0.5, 0.0, 0.5, 0.5, texture)
        aabb2 = add_triangle!(renderer, renderer.state.fill_color, d, a, c, 0.0, 0.5, 0.0, 0.0, 0.5, 0.5, texture)
        return AABB(min_pairwise(aabb1.min, aabb2.min), max_pairwise(aabb1.max, aabb2.max))
    end

    function add_stroke_rectangle!(renderer::SoftwareRenderer3D, a::Vec3D, b::Vec3D, c::Vec3D, d::Vec3D, texture::Ptr{SDL_Texture} = Ptr{SDL_Texture}(C_NULL))::AABB
        aabb1 = add_triangle!(renderer, renderer.state.stroke_color, a, b, c, 0.5, 0.5, 1.0, 0.5, 1.0, 1.0, texture)
        aabb2 = add_triangle!(renderer, renderer.state.stroke_color, d, a, c, 0.5, 1.0, 0.5, 0.5, 1.0, 1.0, texture)
        return AABB(min_pairwise(aabb1.min, aabb2.min), max_pairwise(aabb1.max, aabb2.max))
    end

    # Add box
    function add_box!(renderer::SoftwareRenderer3D, box::RenderBox)::AABB
        # Box vertices
        p1 = Vec3D(-0.5, +0.5, +0.5, 1.0)
        p2 = Vec3D(+0.5, +0.5, +0.5, 1.0)
        p3 = Vec3D(+0.5, -0.5, +0.5, 1.0)
        p4 = Vec3D(-0.5, -0.5, +0.5, 1.0)
        p5 = Vec3D(-0.5, +0.5, -0.5, 1.0)
        p6 = Vec3D(+0.5, +0.5, -0.5, 1.0)
        p7 = Vec3D(+0.5, -0.5, -0.5, 1.0)
        p8 = Vec3D(-0.5, -0.5, -0.5, 1.0)
        
        # Save current state
        old_fill = renderer.state.fill_color
        old_stroke = renderer.state.stroke_color
        old_transform = renderer.state.transform
        
        # Apply box transformation
        renderer.state.fill_color = box.fill_color
        renderer.state.stroke_color = box.stroke_color
        
        # Apply transformations
        box_transform = translation_matrix(box.position.x, box.position.y, box.position.z) *
                       rotation_matrix(box.rotation.x, box.rotation.y, box.rotation.z) *
                       scaling_matrix(box.dimensions.x, box.dimensions.y, box.dimensions.z)
        
        renderer.state.transform = old_transform * box_transform
        
        # Add faces
        aabb = AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        
        # Fill faces
        faces = [
            (p1, p2, p3, p4),  # front
            (p2, p6, p7, p3),  # right
            (p6, p5, p8, p7),  # back
            (p5, p1, p4, p8),  # left
            (p5, p6, p2, p1),  # top
            (p4, p3, p7, p8)   # bottom
        ]
        
        for face in faces
            face_aabb = add_fill_rectangle!(renderer, face[1], face[2], face[3], face[4])
            aabb = AABB(min_pairwise(aabb.min, face_aabb.min), max_pairwise(aabb.max, face_aabb.max))
        end
        
        # Stroke faces
        for face in faces
            face_aabb = add_stroke_rectangle!(renderer, face[1], face[2], face[3], face[4])
            aabb = AABB(min_pairwise(aabb.min, face_aabb.min), max_pairwise(aabb.max, face_aabb.max))
        end
        
        # Restore state
        renderer.state.fill_color = old_fill
        renderer.state.stroke_color = old_stroke
        renderer.state.transform = old_transform
        
        return aabb
    end

    # Helper function to convert Vec3D color to SDL_Color
    function vec3d_to_sdl_color(color::Vec3D, alpha::Float64 = 1.0)::SDL_Color
        r = clamp(round(Int, color.x * 255), 0, 255)
        g = clamp(round(Int, color.y * 255), 0, 255)
        b = clamp(round(Int, color.z * 255), 0, 255)
        a = clamp(round(Int, alpha * 255), 0, 255)
        return SDL_Color(r, g, b, a)
    end



    # Load SDL texture for rendering
    function load_sdl_texture(renderer::SoftwareRenderer3D, texture_path::String)::Ptr{SDL_Texture}
        # Check cache first
        if haskey(renderer.texture_cache, texture_path)
            return renderer.texture_cache[texture_path]
        end
        
        # Load texture using SDL_image
        surface = SDL2.IMG_Load(texture_path)
        if surface == C_NULL
            @warn "Failed to load texture: $texture_path - $(unsafe_string(SDL_GetError()))"
            return Ptr{SDL_Texture}(C_NULL)
        end
        
        # Create texture from surface
        texture = SDL_CreateTextureFromSurface(JulGame.Renderer, surface)
        SDL_FreeSurface(surface)
        
        if texture == C_NULL
            @warn "Failed to create texture from surface: $texture_path - $(unsafe_string(SDL_GetError()))"
            return Ptr{SDL_Texture}(C_NULL)
        end
        
        # Cache the texture
        renderer.texture_cache[texture_path] = texture
        @info "Loaded SDL texture: $texture_path"
        
        return texture
    end

    # Delegate to the MeshLoaderIntegration module
    function load_mesh_from_file!(renderer::SoftwareRenderer3D, file_path::String, 
                                 position::Vec3D = Vec3D(0, 0, 0),
                                 rotation::Vec3D = Vec3D(0, 0, 0),
                                 scale::Vec3D = Vec3D(1, 1, 1),
                                 fill_color::SDL_Color = SDL_Color(255, 255, 255, 255),
                                 stroke_color::SDL_Color = SDL_Color(0, 0, 0, 255))::Union{RenderMesh, Nothing}
        
        if !MESHIO_AVAILABLE
            @error "MeshIO not available. Cannot load 3D files. Install with: using Pkg; Pkg.add([\"FileIO\", \"MeshIO\"])"
            return nothing
        end
        
        return MeshLoaderIntegrationModule.load_mesh_from_file!(renderer, file_path, position, rotation, scale, fill_color, stroke_color)
    end

    # Render a mesh
    function add_mesh!(renderer::SoftwareRenderer3D, mesh::RenderMesh)::AABB
        if isempty(mesh.vertices) || isempty(mesh.faces)
            return AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        end
        
        # Save current state
        old_fill = renderer.state.fill_color
        old_stroke = renderer.state.stroke_color
        old_transform = renderer.state.transform
        
        # Apply mesh transformation
        renderer.state.fill_color = mesh.default_fill_color
        renderer.state.stroke_color = mesh.default_stroke_color
        
        # Apply transformations with safety checks
        try
            mesh_transform = translation_matrix(mesh.position.x, mesh.position.y, mesh.position.z) *
                            rotation_matrix(mesh.rotation.x, mesh.rotation.y, mesh.rotation.z) *
                            scaling_matrix(mesh.scale.x, mesh.scale.y, mesh.scale.z)
            
            renderer.state.transform = old_transform * mesh_transform
        catch e
            @error "Error creating mesh transformation matrix: $e"
            # Use identity transform as fallback
            renderer.state.transform = old_transform
        end
        
        # Render all faces
        aabb = AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        
        # Debug: Print mesh information
        if length(renderer.triangles) == 0  # Only print once per frame
            @info "Rendering mesh: use_materials=$(mesh.use_materials), materials=$(length(mesh.materials)), faces=$(length(mesh.faces))"
            @info "Default fill color: $(mesh.default_fill_color)"
            if !isempty(mesh.materials)
                for (name, material) in mesh.materials
                    @info "Material '$name': has_texture=$(material.has_texture), texture_path='$(material.texture_path)', diffuse=$(material.diffuse_color)"
                end
            end
        end
        
        for (face_idx, face) in enumerate(mesh.faces)
            if length(face.vertex_indices) >= 3
                # Get vertices for this face
                v1 = mesh.vertices[face.vertex_indices[1]]
                v2 = mesh.vertices[face.vertex_indices[2]]
                v3 = mesh.vertices[face.vertex_indices[3]]
                
                # Calculate face normal for lighting
                edge1 = v2 - v1
                edge2 = v3 - v1
                normal = normalize(cross(edge1, edge2))

                # Determine color and texture to use
                face_color_vec = Vec3D(1,1,1) # Default to white
                face_texture = Ptr{SDL_Texture}(C_NULL)
                alpha = 1.0

                if mesh.use_materials && haskey(mesh.materials, face.material_name)
                    material = mesh.materials[face.material_name]
                    alpha = material.alpha
                    
                    # Load SDL texture if available
                    if material.has_texture && isfile(material.texture_path)
                        face_texture = load_sdl_texture(renderer, material.texture_path)
                        if face_texture != Ptr{SDL_Texture}(C_NULL)
                            # Use white color to let texture show through
                            face_color_vec = Vec3D(1.0, 1.0, 1.0) # White for texturing
                            # Debug: only print for first few faces to avoid spam
                            if face_idx <= 3
                                @info "Face $face_idx: Using SDL texture '$(material.texture_path)' for material '$(face.material_name)'"
                            end
                        else
                            # Fallback to texture average color if SDL texture loading failed
                            texture_color = load_texture_average_color(material.texture_path)
                            face_color_vec = texture_color
                            if face_idx <= 3
                                @info "Face $face_idx: SDL texture failed, using average color for '$(face.material_name)'"
                            end
                        end
                    else
                        # Use solid diffuse color
                        face_color_vec = material.diffuse_color
                        # Debug: only print for first few faces to avoid spam
                        if face_idx <= 3
                            @info "Face $face_idx: Using material '$(face.material_name)' with diffuse color $(material.diffuse_color)"
                        end
                    end
                else
                    # Fallback to default mesh color if no material is found
                    face_color_vec = Vec3D(mesh.default_fill_color.r/255.0, mesh.default_fill_color.g/255.0, mesh.default_fill_color.b/255.0)
                    alpha = mesh.default_fill_color.a/255.0
                    # Debug: only print for first few faces to avoid spam
                    if face_idx <= 3
                        @info "Face $face_idx: No material found for face material '$(face.material_name)', using default color $(face_color_vec)"
                    end
                end
                
                # Apply lighting
                light_adjusted_color = apply_lighting(face_color_vec, normal, renderer.light_direction)
                final_color = vec3d_to_sdl_color(light_adjusted_color, alpha)
                
                if face_idx <= 3 # Log the final color for the first 3 faces of each mesh
                    @info "Face $face_idx: Final color after lighting: RGBA($(final_color.r), $(final_color.g), $(final_color.b), $(final_color.a))"
                end

                # Get UV coordinates for this face
                u1, v1_uv, u2, v2_uv, u3, v3_uv = 0.0, 0.0, 1.0, 0.0, 1.0, 1.0  # Default UV coordinates
                
                # Use actual UV coordinates if available
                if !isempty(mesh.uv_coordinates) && length(face.uv_indices) >= 3
                    try
                        # Get UV coordinates from the mesh (handle 0-based indices from OBJ)
                        uv1_idx = face.uv_indices[1]
                        uv2_idx = face.uv_indices[2]  
                        uv3_idx = face.uv_indices[3]
                        
                        if uv1_idx > 0 && uv1_idx <= length(mesh.uv_coordinates)
                            uv1 = mesh.uv_coordinates[uv1_idx]
                            u1, v1_uv = uv1.u, uv1.v
                        end
                        
                        if uv2_idx > 0 && uv2_idx <= length(mesh.uv_coordinates)
                            uv2 = mesh.uv_coordinates[uv2_idx]
                            u2, v2_uv = uv2.u, uv2.v
                        end
                        
                        if uv3_idx > 0 && uv3_idx <= length(mesh.uv_coordinates)
                            uv3 = mesh.uv_coordinates[uv3_idx]
                            u3, v3_uv = uv3.u, uv3.v
                        end
                        
                        # Debug UV coordinates for first few faces
                        if face_idx <= 3
                            @info "Face $face_idx UV coordinates: ($(u1), $(v1_uv)), ($(u2), $(v2_uv)), ($(u3), $(v3_uv))"
                        end
                    catch e
                        @warn "Error getting UV coordinates for face $face_idx: $e, using defaults"
                    end
                end

                # Add triangle with material color and texture
                # Check for invalid values before calling add_triangle!
                if any(isnan, [v1.x, v1.y, v1.z, v2.x, v2.y, v2.z, v3.x, v3.y, v3.z]) || 
                   any(isinf, [v1.x, v1.y, v1.z, v2.x, v2.y, v2.z, v3.x, v3.y, v3.z])
                    @warn "Skipping triangle with invalid vertex coordinates: v1=$v1, v2=$v2, v3=$v3"
                    continue
                end
                
                face_aabb = add_triangle!(renderer, final_color, v1, v2, v3, u1, v1_uv, u2, v2_uv, u3, v3_uv, face_texture)
                aabb = AABB(min_pairwise(aabb.min, face_aabb.min), max_pairwise(aabb.max, face_aabb.max))
            end
        end
        
        # Restore state
        renderer.state.fill_color = old_fill
        renderer.state.stroke_color = old_stroke
        renderer.state.transform = old_transform
        
        return aabb
    end

    # Push/pop state
    function push_state!(renderer::SoftwareRenderer3D)
        # Prevent stack overflow by limiting stack depth
        if length(renderer.state_stack) > 10
            @warn "State stack depth exceeded 10, clearing stack to prevent overflow"
            empty!(renderer.state_stack)
        end
        
        push!(renderer.state_stack, RenderState())
        renderer.state_stack[end].transform = renderer.state.transform
        renderer.state_stack[end].fill_color = renderer.state.fill_color
        renderer.state_stack[end].stroke_color = renderer.state.stroke_color
    end

    function pop_state!(renderer::SoftwareRenderer3D)
        if !isempty(renderer.state_stack)
            renderer.state = pop!(renderer.state_stack)
        end
    end

    function apply_transform!(renderer::SoftwareRenderer3D, matrix::Mat4x4)
        new_transform = renderer.state.transform * matrix
        
        # Check for matrix overflow/invalid values
        for row in new_transform.rows
            for val in [row.x, row.y, row.z, row.w]
                if isnan(val) || isinf(val) || abs(val) > 1e12
                    @warn "Transform matrix overflow detected, resetting to identity"
                    renderer.state.transform = Mat4x4()
                    return
                end
            end
        end
        
        renderer.state.transform = new_transform
    end

    # Flush triangles (render them)
    function flush_triangles!(renderer::SoftwareRenderer3D)::Int
        if isempty(renderer.triangles)
            return 0
        end
        
        # Sort vertices in each triangle by z
        for triangle in renderer.triangles
            sort!(triangle.vertices, by = v -> v.z)
        end
        
        # Sort triangles by average z
        sort!(renderer.triangles, by = tri -> sum(v.z for v in tri.vertices) / 3)
        
        if renderer.reverse_sort_triangles
            reverse!(renderer.triangles)
        end
        
        # Group triangles by texture
        texture_groups = Dict{Ptr{SDL_Texture}, Vector{Triangle3D}}()
        for triangle in renderer.triangles
            texture = triangle.texture
            if !haskey(texture_groups, texture)
                texture_groups[texture] = Triangle3D[]
            end
            push!(texture_groups[texture], triangle)
        end
        
        # Render triangles grouped by texture
        triangle_count = 0
        for (texture, triangles) in texture_groups
            # Convert all triangles for this texture to SDL vertices
            sdl_vertices = SDL_Vertex[]
            for triangle in triangles
                vertices = triangle.vertices
                append!(sdl_vertices, [
                    SDL_Vertex(SDL_FPoint(vertices[1].x, vertices[1].y), vertices[1].color, SDL_FPoint(vertices[1].u, vertices[1].v)),
                    SDL_Vertex(SDL_FPoint(vertices[2].x, vertices[2].y), vertices[2].color, SDL_FPoint(vertices[2].u, vertices[2].v)),
                    SDL_Vertex(SDL_FPoint(vertices[3].x, vertices[3].y), vertices[3].color, SDL_FPoint(vertices[3].u, vertices[3].v))
                ])
            end
            
            # Render all triangles with this texture in one call
            result = SDL_RenderGeometry(JulGame.Renderer, texture, sdl_vertices, length(sdl_vertices), C_NULL, 0)
            if result < 0
                println("SDL_RenderGeometry failed: ", unsafe_string(SDL_GetError()))
            else
                triangle_count += length(triangles)
            end
        end
        
        # Clear triangles
        empty!(renderer.triangles)
        
        return triangle_count
    end

    # Component interface implementations
    function Component.initialize(this::SoftwareRenderer3D, main)
        windowSize = main.windowManager.windowSize
        this.aspect_ratio = windowSize.x / windowSize.y
    end

    function Component.update(this::SoftwareRenderer3D, deltaTime::Float64)
        if !this.parent.isActive
            return
        end

        # Only use internal camera controls if no engine camera is available
        if JulGame.IS_DEBUG && JulGame.MAIN.scene.camera === nothing
            move_speed = 5.0 * deltaTime
            rot_speed = π * deltaTime
            
            # Movement
            if JulGame.InputModule.get_button_held_down("A")
                this.camera_position.x -= move_speed
            elseif JulGame.InputModule.get_button_held_down("D")
                this.camera_position.x += move_speed
            end
            
            if JulGame.InputModule.get_button_held_down("W")
                this.camera_position.z -= move_speed
            elseif JulGame.InputModule.get_button_held_down("S")
                this.camera_position.z += move_speed
            end
            
            if JulGame.InputModule.get_button_held_down("Q")
                this.camera_position.y -= move_speed
            elseif JulGame.InputModule.get_button_held_down("E")
                this.camera_position.y += move_speed
            end
            
            # Rotation
            if JulGame.InputModule.get_button_held_down("Left")
                this.camera_rotation.y += rot_speed
            elseif JulGame.InputModule.get_button_held_down("Right")
                this.camera_rotation.y -= rot_speed
            end
            
            if JulGame.InputModule.get_button_held_down("Up")
                this.camera_rotation.x += rot_speed
            elseif JulGame.InputModule.get_button_held_down("Down")
                this.camera_rotation.x -= rot_speed
            end
            
            # Reset camera
            if JulGame.InputModule.get_button_pressed("R")
                this.camera_position = Vec3D(0, 0, 0)
                this.camera_rotation = Vec3D(0, 0, 0)
                this.camera_zoom = Vec3D(1, 1, 1)
            end
        end
        
        # Handle perspective toggle regardless of camera system
        if JulGame.IS_DEBUG && JulGame.InputModule.get_button_pressed("P")
            this.perspective_enabled = !this.perspective_enabled
            this.reverse_sort_triangles = !this.perspective_enabled
        end
        
        # Animate the first box
        if !isempty(this.boxes)
            this.boxes[1].rotation.y += π * deltaTime
            this.boxes[1].rotation.x += π * 0.5 * deltaTime
        end
    end

    function Component.render(this::SoftwareRenderer3D, main)
        windowSize = main.windowManager.windowSize
        width = Float64(windowSize.x)
        height = Float64(windowSize.y)
        
        # Clear triangles
        empty!(this.triangles)
        
        # Clear state stack to prevent accumulation
        empty!(this.state_stack)
        
        # Reset transform to identity matrix to prevent overflow
        this.state.transform = Mat4x4()
        
        # Setup render state
        push_state!(this)
        
        # Apply viewport transform
        apply_transform!(this, viewport_matrix(Float64(width), Float64(height)))
        
        # Apply projection
        if this.perspective_enabled
            apply_transform!(this, perspective_matrix(this.fov, this.aspect_ratio, this.near, this.far))
        else
            # Orthographic projection
            scale = 0.04 * height / width
            apply_transform!(this, scaling_matrix(Float64(scale), Float64(scale), Float64(scale)))
        end
        
        # Use engine's camera if available, otherwise fall back to internal camera
        if main.scene.camera !== nothing
            # Use the engine's camera system (controlled by Manager.jl)
            engine_camera = main.scene.camera
            camera_pos = Vec3D(Float64(engine_camera.position.x), Float64(engine_camera.position.y), Float64(engine_camera.position.z))
            camera_yaw = Float64(engine_camera.yaw)
            camera_pitch = Float64(engine_camera.pitch)
            
            # Convert yaw/pitch to rotation radians
            yaw_rad = deg2rad(camera_yaw)
            pitch_rad = deg2rad(camera_pitch)
            
            # Apply camera transform
            apply_transform!(this, scaling_matrix(Float64(this.camera_zoom.x), Float64(this.camera_zoom.y), 1.0))
            apply_transform!(this, translation_matrix(0.0, 0.0, -20.0))
            apply_transform!(this, rotation_matrix(-pitch_rad, -yaw_rad, 0.0))
            apply_transform!(this, translation_matrix(-camera_pos.x, -camera_pos.y, -camera_pos.z))
        else
            # Fall back to internal camera system
            apply_transform!(this, scaling_matrix(Float64(this.camera_zoom.x), Float64(this.camera_zoom.y), 1.0))
            apply_transform!(this, translation_matrix(0.0, 0.0, -20.0))
            apply_transform!(this, rotation_matrix(Float64(-this.camera_rotation.x), Float64(-this.camera_rotation.y), Float64(-this.camera_rotation.z)))
            apply_transform!(this, translation_matrix(Float64(-this.camera_position.x), Float64(-this.camera_position.y), Float64(-this.camera_position.z)))
        end
        
        # Render all boxes
        for box in this.boxes
            add_box!(this, box)
        end
        
        # Render all meshes
        for mesh in this.meshes
            add_mesh!(this, mesh)
        end
        
        pop_state!(this)
        
        # Flush all triangles
        triangle_count = flush_triangles!(this)
        
        if JulGame.IS_DEBUG
            println("Rendered $triangle_count triangles")
        end
    end

    function Component.destroy(this::SoftwareRenderer3D)
        # Clean up cached textures
        for (path, texture) in this.texture_cache
            if texture != C_NULL
                SDL_DestroyTexture(texture)
            end
        end
        empty!(this.texture_cache)
        
        empty!(this.triangles)
        empty!(this.boxes)
        empty!(this.meshes)
        empty!(this.state_stack)
    end

    # Utility functions for users
    function add_box!(renderer::SoftwareRenderer3D, position::Vec3D, dimensions::Vec3D, rotation::Vec3D, 
                     fill_color::SDL_Color, stroke_color::SDL_Color)
        box = RenderBox(dimensions, position, rotation, fill_color, stroke_color)
        push!(renderer.boxes, box)
        return box
    end

    function clear_boxes!(renderer::SoftwareRenderer3D)
        empty!(renderer.boxes)
    end

    function clear_meshes!(renderer::SoftwareRenderer3D)
        empty!(renderer.meshes)
    end

    function clear_all!(renderer::SoftwareRenderer3D)
        empty!(renderer.boxes)
        empty!(renderer.meshes)
    end

    function set_camera_position!(renderer::SoftwareRenderer3D, position::Vec3D)
        renderer.camera_position = position
    end

    function set_camera_rotation!(renderer::SoftwareRenderer3D, rotation::Vec3D)
        renderer.camera_rotation = rotation
    end

    # Convenience function to load and add a mesh in one call
    function add_mesh_from_file!(renderer::SoftwareRenderer3D, file_path::String, 
                                position::Vec3D = Vec3D(0, 0, 0),
                                rotation::Vec3D = Vec3D(0, 0, 0),
                                scale::Vec3D = Vec3D(1, 1, 1),
                                fill_color::SDL_Color = SDL_Color(255, 255, 255, 255),
                                stroke_color::SDL_Color = SDL_Color(0, 0, 0, 255))::Union{RenderMesh, Nothing}
        return load_mesh_from_file!(renderer, file_path, position, rotation, scale, fill_color, stroke_color)
    end

    # Get mesh by file path
    function get_mesh_by_path(renderer::SoftwareRenderer3D, file_path::String)::Union{RenderMesh, Nothing}
        for mesh in renderer.meshes
            if mesh.file_path == file_path
                return mesh
            end
        end
        return nothing
    end

    # Remove mesh by file path
    function remove_mesh_by_path!(renderer::SoftwareRenderer3D, file_path::String)::Bool
        for (i, mesh) in enumerate(renderer.meshes)
            if mesh.file_path == file_path
                deleteat!(renderer.meshes, i)
                return true
            end
        end
        return false
    end

    # Perspective correction configuration functions
    function enable_perspective_subdivision!(renderer::SoftwareRenderer3D, enable::Bool = true)
        renderer.enable_perspective_subdivision = enable
    end

    function set_subdivision_thresholds!(renderer::SoftwareRenderer3D; 
                                        area_threshold::Float64 = 10000.0,
                                        z_ratio_threshold::Float64 = 1.5,
                                        max_depth::Int = 3)
        renderer.subdivision_threshold_area = area_threshold
        renderer.subdivision_threshold_z_ratio = z_ratio_threshold
        renderer.max_subdivision_depth = max_depth
    end

    # Get current perspective correction settings
    function get_perspective_settings(renderer::SoftwareRenderer3D)
        return (
            enabled = renderer.enable_perspective_subdivision,
            area_threshold = renderer.subdivision_threshold_area,
            z_ratio_threshold = renderer.subdivision_threshold_z_ratio,
            max_depth = renderer.max_subdivision_depth
        )
    end

    # Simple lighting calculation
    function apply_lighting(color::Vec3D, normal::Vec3D, light_dir::Vec3D)::Vec3D
        # Normalize light direction
        light_dir_normalized = normalize(light_dir)
        
        # Calculate dot product (how much the face is pointing towards the light)
        dp = dot(normal, light_dir_normalized)
        
        # Clamp the dot product to be between ambient and full brightness
        intensity = clamp(dp, 0.2, 1.0) # Using 0.2 for some ambient light
        
        # Apply intensity to the color
        return Vec3D(color.x * intensity, color.y * intensity, color.z * intensity, color.w)
    end

end 