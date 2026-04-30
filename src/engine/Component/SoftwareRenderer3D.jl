module SoftwareRenderer3DModule
    using ..JulGame
    using ..JulGame.Math
    using ..JulGame.SDL2
    using ..JulGame.SDL2.LibSDL2
    using ..JulGame.Component
    using ..JulGame.InputModule
    
    # Import MeshIO and FileIO for 3D file loading
    using FileIO #, MeshIO
    using GeometryBasics
    global MESHIO_AVAILABLE = false #true
    
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
    export LightType, Light3D, add_light!, remove_light!, clear_lights!, set_ambient_light!
    export enable_lighting!, disable_lighting!, enable_shadows!, disable_shadows!
    export enable_profiling!, disable_profiling!, print_profiling_stats!, get_profiling_stats, enable_fast_sort!, enable_cached_sort!

    # Lighting system enums and structures
    @enum LightType begin
        DIRECTIONAL_LIGHT = 1
        POINT_LIGHT = 2
        SPOT_LIGHT = 3
    end

    # Light structure for the lighting system
    mutable struct Light3D
        type::LightType
        position::Vec3D          # Position in world space (for point/spot lights)
        direction::Vec3D         # Direction (for directional/spot lights)
        color::Vec3D            # RGB color (0.0 to 1.0)
        intensity::Float64      # Light intensity multiplier
        range::Float64          # Range for point/spot lights
        spot_angle::Float64     # Cone angle for spot lights (in radians)
        cast_shadows::Bool      # Whether this light casts shadows
        shadow_bias::Float64    # Bias to prevent shadow acne
        enabled::Bool           # Whether this light is active
        
        function Light3D(type::LightType = DIRECTIONAL_LIGHT, 
                        position::Vec3D = Vec3D(0, 10, 0), 
                        direction::Vec3D = Vec3D(0, -1, 0),
                        color::Vec3D = Vec3D(1, 1, 1),
                        intensity::Float64 = 1.0,
                        range::Float64 = 100.0,
                        spot_angle::Float64 = π/4,
                        cast_shadows::Bool = true,
                        shadow_bias::Float64 = 0.001,
                        enabled::Bool = true)
            new(type, position, normalize(direction), color, intensity, range, spot_angle, cast_shadows, shadow_bias, enabled)
        end
    end

    # UV coordinate normalization function
    function normalize_uv_coordinate(uv_coord::Float64)::Float64
        # For coordinates in the typical range [-1, 1], normalize to [0, 1]
        # This handles common cases like coordinates from -1 to 1
        if uv_coord >= -1.0 && uv_coord <= 1.0
            return (uv_coord + 1.0) * 0.5
        end
        # For coordinates outside [-1, 1], use modulo wrapping as fallback
        return mod(uv_coord, 1.0)
    end

    # Re-export from modules
    using .Math3DModule: dot, cross, length_of, normalize, min_pairwise, max_pairwise, 
                        translation_matrix, scaling_matrix, x_rotation_matrix, y_rotation_matrix, 
                        z_rotation_matrix, rotation_matrix, viewport_matrix, perspective_matrix, 
                        perspective_divide!
    using .MeshLoader3DModule: parse_obj_file, parse_mtl_file, parse_obj_materials, load_texture_average_color

    # Performance profiling structure
    mutable struct RenderProfiler
        # Flush/render pipeline
        sorting_time::Float64
        grouping_time::Float64
        vertex_conversion_time::Float64
        rendering_time::Float64
        
        # Triangle processing
        triangle_processing_time::Float64  # Time in add_triangle, add_mesh, etc
        transform_time::Float64  # Matrix transformations
        culling_time::Float64  # Backface/frustum culling
        subdivision_time::Float64  # Perspective subdivision
        
        # Scene setup
        camera_setup_time::Float64  # Camera matrix calculations
        mesh_rendering_time::Float64  # Time in add_mesh!
        box_rendering_time::Float64  # Time in add_box!
        
        # Detailed mesh rendering breakdown
        mesh_vertex_access_time::Float64  # Getting vertices from mesh
        mesh_normal_calc_time::Float64  # Normal calculations
        mesh_material_lookup_time::Float64  # Material dictionary lookups
        mesh_texture_check_time::Float64  # Texture file checks
        mesh_lighting_time::Float64  # Lighting calculations
        mesh_uv_processing_time::Float64  # UV coordinate processing
        mesh_triangle_add_time::Float64  # Time in add_triangle! calls
        
        # Detailed triangle add breakdown
        triangle_create_time::Float64  # Triangle3D struct creation
        triangle_depth_bias_time::Float64  # Depth bias calculation
        triangle_push_time::Float64  # push! to triangles array
        triangle_aabb_time::Float64  # AABB calculation
        
        # Detailed lighting breakdown
        lighting_light_contrib_time::Float64  # calculate_light_contribution
        lighting_shadow_time::Float64  # calculate_shadow_factor
        lighting_ambient_time::Float64  # Ambient light calculations
        
        # Detailed material lookup breakdown
        material_dict_lookup_time::Float64  # Dictionary haskey/get
        material_color_conv_time::Float64  # Color conversions
        
        # Overall
        total_time::Float64
        frame_count::Int
        skipped_sorts::Int  # Count frames where sort was skipped due to caching
        
        function RenderProfiler()
            new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0)
        end
    end
    
    # Print profiling results
    function print_profile(profiler::RenderProfiler)
        if profiler.frame_count == 0
            return
        end
        
        # Calculate averages
        avg_sort = profiler.sorting_time / profiler.frame_count * 1000
        avg_group = profiler.grouping_time / profiler.frame_count * 1000
        avg_convert = profiler.vertex_conversion_time / profiler.frame_count * 1000
        avg_render = profiler.rendering_time / profiler.frame_count * 1000
        avg_tri_process = profiler.triangle_processing_time / profiler.frame_count * 1000
        avg_transform = profiler.transform_time / profiler.frame_count * 1000
        avg_culling = profiler.culling_time / profiler.frame_count * 1000
        avg_subdiv = profiler.subdivision_time / profiler.frame_count * 1000
        avg_camera = profiler.camera_setup_time / profiler.frame_count * 1000
        avg_mesh = profiler.mesh_rendering_time / profiler.frame_count * 1000
        avg_box = profiler.box_rendering_time / profiler.frame_count * 1000
        avg_total = profiler.total_time / profiler.frame_count * 1000
        
        skip_percent = profiler.skipped_sorts / profiler.frame_count * 100
        
        println("\n=== COMPREHENSIVE RENDER PROFILING (avg over $(profiler.frame_count) frames) ===")
        avg_mesh_vertex = profiler.mesh_vertex_access_time / profiler.frame_count * 1000
        avg_mesh_normal = profiler.mesh_normal_calc_time / profiler.frame_count * 1000
        avg_mesh_material = profiler.mesh_material_lookup_time / profiler.frame_count * 1000
        avg_mesh_texture = profiler.mesh_texture_check_time / profiler.frame_count * 1000
        avg_mesh_lighting = profiler.mesh_lighting_time / profiler.frame_count * 1000
        avg_mesh_uv = profiler.mesh_uv_processing_time / profiler.frame_count * 1000
        avg_mesh_tri_add = profiler.mesh_triangle_add_time / profiler.frame_count * 1000
        
        println("=== SCENE SETUP ===")
        println("Camera Setup:      $(round(avg_camera, digits=3)) ms ($(round(profiler.camera_setup_time/profiler.total_time*100, digits=1))%)")
        println("Mesh Rendering:    $(round(avg_mesh, digits=3)) ms ($(round(profiler.mesh_rendering_time/profiler.total_time*100, digits=1))%)")
        if profiler.mesh_rendering_time > 0
            println("  - Vertex Access: $(round(avg_mesh_vertex, digits=3)) ms ($(round(profiler.mesh_vertex_access_time/profiler.mesh_rendering_time*100, digits=1))%)")
            println("  - Normal Calc:   $(round(avg_mesh_normal, digits=3)) ms ($(round(profiler.mesh_normal_calc_time/profiler.mesh_rendering_time*100, digits=1))%)")
            println("  - Material Lookup: $(round(avg_mesh_material, digits=3)) ms ($(round(profiler.mesh_material_lookup_time/profiler.mesh_rendering_time*100, digits=1))%)")
            println("  - Texture Check: $(round(avg_mesh_texture, digits=3)) ms ($(round(profiler.mesh_texture_check_time/profiler.mesh_rendering_time*100, digits=1))%)")
            println("  - Lighting:      $(round(avg_mesh_lighting, digits=3)) ms ($(round(profiler.mesh_lighting_time/profiler.mesh_rendering_time*100, digits=1))%)")
            println("  - UV Processing: $(round(avg_mesh_uv, digits=3)) ms ($(round(profiler.mesh_uv_processing_time/profiler.mesh_rendering_time*100, digits=1))%)")
            println("  - Triangle Add:  $(round(avg_mesh_tri_add, digits=3)) ms ($(round(profiler.mesh_triangle_add_time/profiler.mesh_rendering_time*100, digits=1))%)")
            
            # Detailed triangle add breakdown
            if profiler.mesh_triangle_add_time > 0
                avg_tri_create = profiler.triangle_create_time / profiler.frame_count * 1000
                avg_tri_bias = profiler.triangle_depth_bias_time / profiler.frame_count * 1000
                avg_tri_push = profiler.triangle_push_time / profiler.frame_count * 1000
                avg_tri_aabb = profiler.triangle_aabb_time / profiler.frame_count * 1000
                println("    Triangle Add Breakdown:")
                println("      - Create:    $(round(avg_tri_create, digits=3)) ms ($(round(profiler.triangle_create_time/profiler.mesh_triangle_add_time*100, digits=1))%)")
                println("      - Depth Bias: $(round(avg_tri_bias, digits=3)) ms ($(round(profiler.triangle_depth_bias_time/profiler.mesh_triangle_add_time*100, digits=1))%)")
                println("      - Push:      $(round(avg_tri_push, digits=3)) ms ($(round(profiler.triangle_push_time/profiler.mesh_triangle_add_time*100, digits=1))%)")
                println("      - AABB:      $(round(avg_tri_aabb, digits=3)) ms ($(round(profiler.triangle_aabb_time/profiler.mesh_triangle_add_time*100, digits=1))%)")
            end
            
            # Detailed lighting breakdown
            if profiler.mesh_lighting_time > 0
                avg_light_contrib = profiler.lighting_light_contrib_time / profiler.frame_count * 1000
                avg_light_shadow = profiler.lighting_shadow_time / profiler.frame_count * 1000
                avg_light_ambient = profiler.lighting_ambient_time / profiler.frame_count * 1000
                println("    Lighting Breakdown:")
                println("      - Ambient:   $(round(avg_light_ambient, digits=3)) ms ($(round(profiler.lighting_ambient_time/profiler.mesh_lighting_time*100, digits=1))%)")
                println("      - Light Contrib: $(round(avg_light_contrib, digits=3)) ms ($(round(profiler.lighting_light_contrib_time/profiler.mesh_lighting_time*100, digits=1))%)")
                println("      - Shadows:   $(round(avg_light_shadow, digits=3)) ms ($(round(profiler.lighting_shadow_time/profiler.mesh_lighting_time*100, digits=1))%)")
            end
            
            # Detailed material lookup breakdown
            if profiler.mesh_material_lookup_time > 0
                avg_mat_dict = profiler.material_dict_lookup_time / profiler.frame_count * 1000
                avg_mat_conv = profiler.material_color_conv_time / profiler.frame_count * 1000
                println("    Material Lookup Breakdown:")
                println("      - Dict Lookup: $(round(avg_mat_dict, digits=3)) ms ($(round(profiler.material_dict_lookup_time/profiler.mesh_material_lookup_time*100, digits=1))%)")
                println("      - Color Conv:  $(round(avg_mat_conv, digits=3)) ms ($(round(profiler.material_color_conv_time/profiler.mesh_material_lookup_time*100, digits=1))%)")
            end
        end
        println("Box Rendering:     $(round(avg_box, digits=3)) ms ($(round(profiler.box_rendering_time/profiler.total_time*100, digits=1))%)")
        println("=== TRIANGLE PROCESSING ===")
        println("Triangle Process:  $(round(avg_tri_process, digits=3)) ms ($(round(profiler.triangle_processing_time/profiler.total_time*100, digits=1))%)")
        println("  - Transforms:    $(round(avg_transform, digits=3)) ms ($(round(profiler.transform_time/profiler.total_time*100, digits=1))%)")
        println("  - Culling:       $(round(avg_culling, digits=3)) ms ($(round(profiler.culling_time/profiler.total_time*100, digits=1))%)")
        println("  - Subdivision:   $(round(avg_subdiv, digits=3)) ms ($(round(profiler.subdivision_time/profiler.total_time*100, digits=1))%)")
        println("=== RENDER PIPELINE ===")
        println("Sorting:           $(round(avg_sort, digits=3)) ms ($(round(profiler.sorting_time/profiler.total_time*100, digits=1))%) [Skipped: $(round(skip_percent, digits=1))%]")
        println("Grouping:          $(round(avg_group, digits=3)) ms ($(round(profiler.grouping_time/profiler.total_time*100, digits=1))%)")
        println("Vertex Conversion: $(round(avg_convert, digits=3)) ms ($(round(profiler.vertex_conversion_time/profiler.total_time*100, digits=1))%)")
        println("SDL Rendering:     $(round(avg_render, digits=3)) ms ($(round(profiler.rendering_time/profiler.total_time*100, digits=1))%)")
        println("=== SUMMARY ===")
        println("Total Frame:       $(round(avg_total, digits=3)) ms")
        println("===================================================\n")
    end

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
        
        # Performance profiling
        profiler::RenderProfiler
        enable_profiling::Bool
        profile_print_interval::Int  # Print stats every N frames
        
        # Sorting optimization
        use_fast_sort::Bool  # Use QuickSort instead of MergeSort (faster but less stable)
        use_cached_sort::Bool  # Skip sorting if camera hasn't moved much
        last_camera_position::Union{Nothing, Vector3f}
        last_camera_yaw::Float64
        last_camera_pitch::Float64
        camera_move_threshold::Float64  # Don't resort if camera moved less than this
        camera_rotate_threshold::Float64  # Don't resort if camera rotated less than this
        
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
        enable_backface_culling::Bool  # Add backculling toggle
        clockwise_front_faces::Bool    # Add winding order configuration
        
        # Projection properties
        fov::Float64
        aspect_ratio::Float64
        near::Float64
        far::Float64
        
        # Enhanced lighting system
        lights::Vector{Light3D}
        ambient_light::Vec3D
        lighting_enabled::Bool
        shadows_enabled::Bool
        shadow_quality::Int  # 1 = low, 2 = medium, 3 = high
        shadow_map_size::Int
        max_shadow_distance::Float64
        
        # Depth bias configuration for z-fighting prevention
        depth_bias_factor::Float64
        enable_depth_bias::Bool

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
            
            # Initialize profiler
            this.profiler = RenderProfiler()
            this.enable_profiling = false  # Toggle with 'M' key in debug mode
            this.profile_print_interval = 60  # Print every 60 frames
            
            # Initialize sort optimization
            this.use_fast_sort = false  # Use stable MergeSort by default
            this.use_cached_sort = true  # Enable frame coherency by default (huge speedup!)
            this.last_camera_position = nothing
            this.last_camera_yaw = 0.0
            this.last_camera_pitch = 0.0
            this.camera_move_threshold = 0.5  # Skip resort if camera moved < 0.5 units (more lenient)
            this.camera_rotate_threshold = 2.0  # Skip resort if camera rotated < 2 degrees (more lenient)
            
            # Initialize perspective correction settings
            # Optimized: Higher thresholds = less subdivision = better performance
            # Aggressively reduce subdivision - it's taking 51% of triangle processing time
            this.enable_perspective_subdivision = true
            this.subdivision_threshold_area = 50000.0  # Pixels (increased 5x - very large triangles only)
            this.subdivision_threshold_z_ratio = 3.0   # Z depth variation ratio (very high - avoid subdivision)
            this.max_subdivision_depth = 1            # Maximum recursion depth (reduced to 1 - single split max)
            
            this.camera_position = Vec3D(0, 0, 0)
            this.camera_rotation = Vec3D(0, 0, 0)
            this.camera_zoom = Vec3D(1, 1, 1)
            this.perspective_enabled = true
            this.reverse_sort_triangles = false
            this.enable_backface_culling = true
            this.clockwise_front_faces = false
            
            this.fov = π / 3.0  # 60 degrees
            this.aspect_ratio = 1.0
            this.near = 1.0 / 1024.0
            this.far = 1024.0
            
            # Initialize enhanced lighting system
            this.lights = Light3D[]
            this.ambient_light = Vec3D(0.2, 0.2, 0.2)  # Default ambient light
            this.lighting_enabled = true
            this.shadows_enabled = true
            this.shadow_quality = 2  # Medium quality by default
            this.shadow_map_size = 1024
            this.max_shadow_distance = 100.0
            
            # Add default directional light
            default_light = Light3D(DIRECTIONAL_LIGHT, Vec3D(0, 10, 0), Vec3D(0.0, -0.5, -1.0), Vec3D(1.0, 1.0, 0.9), 0.8)
            push!(this.lights, default_light)
            
            # Initialize depth bias configuration
            this.depth_bias_factor = 0.00001  # Small factor for fine-tuning
            this.enable_depth_bias = true     # Enable by default
            
            return this
        end
    end

    # Calculate perspective-correct UV coordinates using subdivision
    function calculate_perspective_correct_uv(u::Float64, v::Float64, z::Float64)::Tuple{Float64, Float64}
        # For now, return original coordinates - subdivision will handle perspective correction
        return (u, v)
    end

    # Backface culling check - returns true if triangle should be culled
    function should_cull_triangle(renderer::SoftwareRenderer3D, a::Vec3D, b::Vec3D, c::Vec3D)::Bool
        # Skip culling if disabled
        if !renderer.enable_backface_culling
            return false
        end
        
        # Calculate triangle normal in view space
        edge1 = Vec3D(b.x - a.x, b.y - a.y, b.z - a.z, 0.0)
        edge2 = Vec3D(c.x - a.x, c.y - a.y, c.z - a.z, 0.0)
        normal = cross(edge1, edge2)
        
        # View vector (assuming camera looks down -Z in view space)
        view_dir = Vec3D(0.0, 0.0, -1.0, 0.0)
        
        # Cull if triangle faces away from camera
        # INVERTED: Your meshes use clockwise winding, so we cull when dot < 0
        return dot(normal, view_dir) < 0.0
    end

    # Check if triangle vertices are in counter-clockwise order when viewed from front
    function is_ccw_winding(a::Vec3D, b::Vec3D, c::Vec3D)::Bool
        # Calculate signed area in screen space (2D projection)
        signed_area = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
        return signed_area > 0.0
    end

    # Screen-space backface culling (more accurate after perspective divide)
    function should_cull_triangle_screen_space(renderer::SoftwareRenderer3D, a::Vec3D, b::Vec3D, c::Vec3D)::Bool
        if !renderer.enable_backface_culling
            return false
        end
        
        # Calculate signed area in screen space
        signed_area = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
        
        # Cull based on winding order configuration
        # If clockwise_front_faces is true: cull when area is negative (CCW triangles)
        # If clockwise_front_faces is false: cull when area is positive (CW triangles)
        return renderer.clockwise_front_faces ? (signed_area < 0.0) : (signed_area > 0.0)
    end

    # Ensure consistent winding order for a triangle
    function ensure_winding_order!(vertices::Vector{Vertex3D}, target_ccw::Bool = true)
        if length(vertices) != 3
            return
        end
        
        a = Vec3D(vertices[1].x, vertices[1].y, vertices[1].z, 1.0)
        b = Vec3D(vertices[2].x, vertices[2].y, vertices[2].z, 1.0)
        c = Vec3D(vertices[3].x, vertices[3].y, vertices[3].z, 1.0)
        
        is_ccw = is_ccw_winding(a, b, c)
        
        # Swap vertices if winding order doesn't match target
        if is_ccw != target_ccw
            vertices[2], vertices[3] = vertices[3], vertices[2]
        end
    end

    # Improved triangle sorting with proper depth handling
    function sort_triangles_by_depth!(renderer::SoftwareRenderer3D)
        # OPTIMIZED: Use closest vertex Z instead of average (faster, no division)
        # For back-to-front sorting, we want furthest triangles first
        sort!(renderer.triangles, by = tri -> max(tri.vertices[1].z, tri.vertices[2].z, tri.vertices[3].z), rev=true)
        
        if renderer.reverse_sort_triangles
            reverse!(renderer.triangles)
        end
    end
    
    # Enhanced triangle sorting with stability for coplanar triangles
    function sort_triangles_by_depth_stable!(renderer::SoftwareRenderer3D)
        # OPTIMIZED: Use max Z directly instead of average (no division, faster)
        # Choice of algorithm based on use_fast_sort flag
        if renderer.use_fast_sort
            # QuickSort: Faster but less stable (may cause minor z-fighting)
            sort!(renderer.triangles, 
                  by = tri -> max(tri.vertices[1].z, tri.vertices[2].z, tri.vertices[3].z), 
                  alg=QuickSort,
                  rev=true)
        else
            # MergeSort: Slower but stable (better for coplanar triangles)
            sort!(renderer.triangles, 
                  by = tri -> max(tri.vertices[1].z, tri.vertices[2].z, tri.vertices[3].z), 
                  alg=MergeSort,
                  rev=true)
        end
        
        if renderer.reverse_sort_triangles
            reverse!(renderer.triangles)
        end
    end

    # Split triangles that intersect for proper ordering (simplified BSP approach)
    function split_intersecting_triangles!(renderer::SoftwareRenderer3D)
        # This is a simplified approach - for production use, implement full BSP
        # For now, we'll use a heuristic: split large triangles that span significant depth
        new_triangles = Triangle3D[]
        
        for triangle in renderer.triangles
            z_min = minimum(v.z for v in triangle.vertices)
            z_max = maximum(v.z for v in triangle.vertices)
            z_range = z_max - z_min
            
            # If triangle spans too much depth, it might intersect others
            if z_range > 5.0  # Threshold for splitting
                # Keep original triangle for now - full BSP implementation would split here
                push!(new_triangles, triangle)
            else
                push!(new_triangles, triangle)
            end
        end
        
        renderer.triangles = new_triangles
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
        
        # Profile subdivision (only at top level to avoid double counting)
        subdiv_start = (renderer.enable_profiling && depth == 0) ? time() : 0.0
        
        # Early exit: if depth is max, never subdivide
        if depth >= renderer.max_subdivision_depth
            should_subdivide = false
        else
            # Calculate triangle size in screen space to determine if subdivision is needed
            # Optimized: Use squared area check to avoid sqrt, compare against squared threshold
            dx1 = b.x - a.x
            dy1 = c.y - a.y
            dx2 = c.x - a.x
            dy2 = b.y - a.y
            screen_area = abs(dx1 * dy1 - dx2 * dy2)
            
            # Early exit if area is too small (most common case)
            if screen_area <= renderer.subdivision_threshold_area
                # Check depth variation only if area threshold not met
                z_min = min(a.z, b.z, c.z)
                z_max = max(a.z, b.z, c.z)
                z_ratio = z_max / max(z_min, 0.001)  # Avoid division by zero
                should_subdivide = z_ratio > renderer.subdivision_threshold_z_ratio
            else
                # Area threshold met - subdivide
                should_subdivide = true
            end
        end
        
        if !should_subdivide
            # Base case: add the triangle without further subdivision
            result = add_triangle_direct!(renderer, color, a, b, c, u1, v1, u2, v2, u3, v3, texture)
            if renderer.enable_profiling && depth == 0
                renderer.profiler.subdivision_time += time() - subdiv_start
            end
            return result
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
        
        if renderer.enable_profiling && depth == 0
            renderer.profiler.subdivision_time += time() - subdiv_start
        end
        
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
        
        # Profile transforms
        transform_start = renderer.enable_profiling ? time() : 0.0
        
        # Transform vertices
        ta = renderer.state.transform * a
        tb = renderer.state.transform * b
        tc = renderer.state.transform * c
        
        # Check if behind camera
        if ta.w <= 0 || tb.w <= 0 || tc.w <= 0
            if renderer.enable_profiling
                renderer.profiler.transform_time += time() - transform_start
            end
            return AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        end
        
        # Store Z values for depth
        z1, z2, z3 = ta.z, tb.z, tc.z
        
        # Perspective divide
        perspective_divide!(ta)
        perspective_divide!(tb)
        perspective_divide!(tc)
        
        if renderer.enable_profiling
            renderer.profiler.transform_time += time() - transform_start
        end
        
        # Profile culling
        cull_start = renderer.enable_profiling ? time() : 0.0
        
        # Perform backface culling in screen space (after perspective divide)
        if should_cull_triangle_screen_space(renderer, ta, tb, tc)
            if renderer.enable_profiling
                renderer.profiler.culling_time += time() - cull_start
            end
            return AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        end
        
        # Frustum culling (basic)
        windowSize = JulGame.MAIN.windowManager.windowSize
        width = windowSize.x
        height = windowSize.y
        
        if (ta.x < 0 && tb.x < 0 && tc.x < 0) ||
           (ta.x > width && tb.x > width && tc.x > width) ||
           (ta.y < 0 && tb.y < 0 && tc.y < 0) ||
           (ta.y > height && tb.y > height && tc.y > height)
            if renderer.enable_profiling
                renderer.profiler.culling_time += time() - cull_start
            end
            return AABB(Vec3D(Inf, Inf, Inf), Vec3D(-Inf, -Inf, -Inf))
        end
        
        if renderer.enable_profiling
            renderer.profiler.culling_time += time() - cull_start
        end
        
        # Profile: Triangle creation
        tri_create_start = renderer.enable_profiling ? time() : 0.0
        triangle = Triangle3D(
            Vertex3D(ta.x, ta.y, z1, color, u1, v1),
            Vertex3D(tb.x, tb.y, z2, color, u2, v2),
            Vertex3D(tc.x, tc.y, z3, color, u3, v3),
            texture
        )
        if renderer.enable_profiling
            renderer.profiler.triangle_create_time += time() - tri_create_start
        end
        
        # Profile: Depth bias
        bias_start = renderer.enable_profiling ? time() : 0.0
        if renderer.enable_depth_bias
            # Use a small bias that moves triangles slightly closer to the camera (negative Z)
            # This ensures objects added later (like items on grass) appear on top
            # Optimized: cache triangle count before push (avoids extra length() call after push)
            triangle_count = length(renderer.triangles)
            depth_bias = -triangle_count * renderer.depth_bias_factor
            # Optimized: direct array access instead of loop iterator
            triangle.vertices[1].z += depth_bias
            triangle.vertices[2].z += depth_bias
            triangle.vertices[3].z += depth_bias
        end
        if renderer.enable_profiling
            renderer.profiler.triangle_depth_bias_time += time() - bias_start
        end
        
        # Profile: Push to array
        push_start = renderer.enable_profiling ? time() : 0.0
        push!(renderer.triangles, triangle)
        if renderer.enable_profiling
            renderer.profiler.triangle_push_time += time() - push_start
        end
        
        # Profile: AABB calculation
        # Optimized: Direct min/max instead of nested min_pairwise calls
        aabb_start = renderer.enable_profiling ? time() : 0.0
        min_pt = Vec3D(min(ta.x, tb.x, tc.x), min(ta.y, tb.y, tc.y), min(ta.z, tb.z, tc.z))
        max_pt = Vec3D(max(ta.x, tb.x, tc.x), max(ta.y, tb.y, tc.y), max(ta.z, tb.z, tc.z))
        result_aabb = AABB(min_pt, max_pt)
        if renderer.enable_profiling
            renderer.profiler.triangle_aabb_time += time() - aabb_start
        end
        
        return result_aabb
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
        
        # Profile overall triangle processing
        tri_start = renderer.enable_profiling ? time() : 0.0
        
        # Use subdivision for better perspective-correct texture mapping
        # This approximates perspective correction by subdividing large or depth-varying triangles
        result = subdivide_triangle_for_perspective(renderer, color, a, b, c, u1, v1, u2, v2, u3, v3, texture, 0)
        
        if renderer.enable_profiling
            renderer.profiler.triangle_processing_time += time() - tri_start
        end
        
        return result
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
        @debug "Loaded SDL texture: $texture_path"
        
        return texture
    end

    # Delegate to the MeshLoaderIntegration module
    function load_mesh_from_file!(renderer::SoftwareRenderer3D, file_path::String, 
                                 position::Vec3D = Vec3D(0, 0, 0),
                                 rotation::Vec3D = Vec3D(0, 0, 0),
                                 scale::Vec3D = Vec3D(1, 1, 1),
                                 fill_color::SDL_Color = SDL_Color(255, 255, 255, 255),
                                 stroke_color::SDL_Color = SDL_Color(0, 0, 0, 255),
                                 normalize_uv::Bool = false)::Union{RenderMesh, Nothing}
        
        if !MESHIO_AVAILABLE
            @error "MeshIO not available. Cannot load 3D files. Install with: using Pkg; Pkg.add([\"FileIO\", \"MeshIO\"])"
            return nothing
        end
        
        return MeshLoaderIntegrationModule.load_mesh_from_file!(renderer, file_path, position, rotation, scale, fill_color, stroke_color, normalize_uv)
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
            # @debug "Rendering mesh: use_materials=$(mesh.use_materials), materials=$(length(mesh.materials)), faces=$(length(mesh.faces))"
            # @debug "Default fill color: $(mesh.default_fill_color)"
            if !isempty(mesh.materials)
                for (name, material) in mesh.materials
                   # @debug "Material '$name': has_texture=$(material.has_texture), texture_path='$(material.texture_path)', diffuse=$(material.diffuse_color)"
                end
            end
        end
        
        for (face_idx, face) in enumerate(mesh.faces)
            if length(face.vertex_indices) >= 3
                # Profile: Vertex access
                vertex_start = renderer.enable_profiling ? time() : 0.0
                v1 = mesh.vertices[face.vertex_indices[1]]
                v2 = mesh.vertices[face.vertex_indices[2]]
                v3 = mesh.vertices[face.vertex_indices[3]]
                if renderer.enable_profiling
                    renderer.profiler.mesh_vertex_access_time += time() - vertex_start
                end
                
                # Profile: Normal calculation
                normal_start = renderer.enable_profiling ? time() : 0.0
                edge1 = v2 - v1
                edge2 = v3 - v1
                normal = normalize(cross(edge1, edge2))
                if renderer.enable_profiling
                    renderer.profiler.mesh_normal_calc_time += time() - normal_start
                end

                # Profile: Material lookup
                material_start = renderer.enable_profiling ? time() : 0.0
                face_color_vec = Vec3D(1,1,1) # Default to white
                face_texture = Ptr{SDL_Texture}(C_NULL)
                alpha = 1.0

                # Profile: Dictionary lookup
                # Optimized: Use get() instead of haskey() + index (single dictionary lookup instead of two)
                dict_start = renderer.enable_profiling ? time() : 0.0
                material = nothing
                if mesh.use_materials
                    # get() with default is faster than haskey() + indexing (single lookup)
                    material = get(mesh.materials, face.material_name, nothing)
                    if material !== nothing
                        alpha = material.alpha
                    end
                end
                if renderer.enable_profiling
                    renderer.profiler.material_dict_lookup_time += time() - dict_start
                end
                
                if material !== nothing
                    
                    # Profile: Texture check (uses cached texture_file_exists)
                    texture_start = renderer.enable_profiling ? time() : 0.0
                    if material.has_texture && material.texture_file_exists
                        face_texture = load_sdl_texture(renderer, material.texture_path)
                        if face_texture != Ptr{SDL_Texture}(C_NULL)
                            face_color_vec = material.diffuse_color
                        else
                            face_color_vec = material.diffuse_color
                        end
                    else
                        face_color_vec = material.diffuse_color
                    end
                    if renderer.enable_profiling
                        renderer.profiler.mesh_texture_check_time += time() - texture_start
                    end
                else
                    # Profile: Color conversion (default material)
                    conv_start = renderer.enable_profiling ? time() : 0.0
                    face_color_vec = Vec3D(mesh.default_fill_color.r/255.0, mesh.default_fill_color.g/255.0, mesh.default_fill_color.b/255.0)
                    alpha = mesh.default_fill_color.a/255.0
                    if renderer.enable_profiling
                        renderer.profiler.material_color_conv_time += time() - conv_start
                    end
                end
                
                # Profile: Color conversion (material diffuse color)
                if material !== nothing
                    conv_start = renderer.enable_profiling ? time() : 0.0
                    # face_color_vec already set from material above
                    if renderer.enable_profiling
                        renderer.profiler.material_color_conv_time += time() - conv_start
                    end
                end
                
                if renderer.enable_profiling
                    renderer.profiler.mesh_material_lookup_time += time() - material_start
                end
                
                # Profile: Lighting calculation
                lighting_start = renderer.enable_profiling ? time() : 0.0
                if renderer.lighting_enabled
                    lighting_factor = calculate_lighting_factor(renderer, normal, v1, v2, v3)
                    
                    if face_texture != Ptr{SDL_Texture}(C_NULL)
                        light_adjusted_color = face_color_vec
                    else
                        light_adjusted_color = Vec3D(face_color_vec.x * lighting_factor,
                                                   face_color_vec.y * lighting_factor,
                                                   face_color_vec.z * lighting_factor,
                                                   face_color_vec.w)
                    end
                else
                    light_adjusted_color = face_color_vec
                    lighting_factor = 1.0
                end
                final_color = vec3d_to_sdl_color(light_adjusted_color, alpha)
                if renderer.enable_profiling
                    renderer.profiler.mesh_lighting_time += time() - lighting_start
                end

                # Profile: UV processing
                uv_start = renderer.enable_profiling ? time() : 0.0
                u1, v1_uv, u2, v2_uv, u3, v3_uv = 0.0, 0.0, 1.0, 0.0, 1.0, 1.0  # Default UV coordinates
                
                if !isempty(mesh.uv_coordinates) && length(face.uv_indices) >= 3
                    try
                        uv1_idx = face.uv_indices[1]
                        uv2_idx = face.uv_indices[2]  
                        uv3_idx = face.uv_indices[3]
                        
                        if uv1_idx > 0 && uv1_idx <= length(mesh.uv_coordinates)
                            uv1 = mesh.uv_coordinates[uv1_idx]
                            if mesh.normalize_uv_coordinates
                                u1 = normalize_uv_coordinate(uv1.u)
                                v1_uv = normalize_uv_coordinate(1.0 - uv1.v)
                            else
                                u1, v1_uv = uv1.u, 1.0 - uv1.v
                            end
                        end
                        
                        if uv2_idx > 0 && uv2_idx <= length(mesh.uv_coordinates)
                            uv2 = mesh.uv_coordinates[uv2_idx]
                            if mesh.normalize_uv_coordinates
                                u2 = normalize_uv_coordinate(uv2.u)
                                v2_uv = normalize_uv_coordinate(1.0 - uv2.v)
                            else
                                u2, v2_uv = uv2.u, 1.0 - uv2.v
                            end
                        end
                        
                        if uv3_idx > 0 && uv3_idx <= length(mesh.uv_coordinates)
                            uv3 = mesh.uv_coordinates[uv3_idx]
                            if mesh.normalize_uv_coordinates
                                u3 = normalize_uv_coordinate(uv3.u)
                                v3_uv = normalize_uv_coordinate(1.0 - uv3.v)
                            else
                                u3, v3_uv = uv3.u, 1.0 - uv3.v
                            end
                        end
                    catch e
                        @warn "Error getting UV coordinates for face $face_idx: $e, using defaults"
                    end
                end
                if renderer.enable_profiling
                    renderer.profiler.mesh_uv_processing_time += time() - uv_start
                end

                # Profile: Triangle addition
                tri_add_start = renderer.enable_profiling ? time() : 0.0
                
                # Check for invalid values
                if any(isnan, [v1.x, v1.y, v1.z, v2.x, v2.y, v2.z, v3.x, v3.y, v3.z]) || 
                   any(isinf, [v1.x, v1.y, v1.z, v2.x, v2.y, v2.z, v3.x, v3.y, v3.z])
                    if renderer.enable_profiling
                        renderer.profiler.mesh_triangle_add_time += time() - tri_add_start
                    end
                    continue
                end
                
                if face_texture != Ptr{SDL_Texture}(C_NULL) && renderer.lighting_enabled
                    lit_color = vec3d_to_sdl_color(Vec3D(lighting_factor, lighting_factor, lighting_factor), alpha)
                    face_aabb = add_triangle!(renderer, lit_color, v1, v2, v3, u1, v1_uv, u2, v2_uv, u3, v3_uv, face_texture)
                else
                    face_aabb = add_triangle!(renderer, final_color, v1, v2, v3, u1, v1_uv, u2, v2_uv, u3, v3_uv, face_texture)
                end
                
                if renderer.enable_profiling
                    renderer.profiler.mesh_triangle_add_time += time() - tri_add_start
                end
                
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
        
        # Start total timing
        frame_start = renderer.enable_profiling ? time() : 0.0
        
        # Count initial triangles (only in debug mode)
        initial_count = JulGame.IS_DEBUG ? length(renderer.triangles) : 0
        
        # Timing: Sorting (with frame coherency optimization)
        sort_start = renderer.enable_profiling ? time() : 0.0
        
        # Check if we need to resort based on camera movement
        needs_resort = true
        if renderer.use_cached_sort && renderer.last_camera_position !== nothing
            # Get current camera state (with safety check)
            camera = JulGame.MAIN.scene.camera
            if camera !== nothing
                # Calculate position delta (Manhattan distance for speed)
                pos_delta = abs(camera.position.x - renderer.last_camera_position.x) +
                           abs(camera.position.y - renderer.last_camera_position.y) +
                           abs(camera.position.z - renderer.last_camera_position.z)
                position_changed = pos_delta > renderer.camera_move_threshold
                
                # Calculate rotation delta (handle wraparound)
                yaw_delta = abs(camera.yaw - renderer.last_camera_yaw)
                if yaw_delta > 180.0
                    yaw_delta = 360.0 - yaw_delta  # Handle 360° wraparound
                end
                pitch_delta = abs(camera.pitch - renderer.last_camera_pitch)
                
                rotation_changed = (yaw_delta > renderer.camera_rotate_threshold) || 
                                  (pitch_delta > renderer.camera_rotate_threshold)
                
                # Only resort if camera moved significantly
                needs_resort = position_changed || rotation_changed
            end
        end
        
        if needs_resort
            sort_triangles_by_depth_stable!(renderer)
            
            # Update cached camera state
            if renderer.use_cached_sort
                camera = JulGame.MAIN.scene.camera
                renderer.last_camera_position = Math.Vector3f(camera.position.x, camera.position.y, camera.position.z)
                renderer.last_camera_yaw = camera.yaw
                renderer.last_camera_pitch = camera.pitch
            end
        else
            # Track skipped sorts for profiling
            if renderer.enable_profiling
                renderer.profiler.skipped_sorts += 1
            end
        end
        
        if renderer.enable_profiling
            renderer.profiler.sorting_time += time() - sort_start
        end
        
        # Timing: Grouping by texture
        group_start = renderer.enable_profiling ? time() : 0.0
        texture_groups = Dict{Ptr{SDL_Texture}, Vector{Triangle3D}}()
        for triangle in renderer.triangles
            texture = triangle.texture
            if !haskey(texture_groups, texture)
                texture_groups[texture] = Triangle3D[]
            end
            push!(texture_groups[texture], triangle)
        end
        if renderer.enable_profiling
            renderer.profiler.grouping_time += time() - group_start
        end
        
        # Timing: Vertex conversion and rendering
        triangle_count = 0
        for (texture, triangles) in texture_groups
            # Timing: Vertex conversion
            convert_start = renderer.enable_profiling ? time() : 0.0
            
            # Pre-allocate SDL vertices array (3 vertices per triangle)
            num_vertices = length(triangles) * 3
            sdl_vertices = Vector{SDL_Vertex}(undef, num_vertices)
            
            # Fill vertices array
            idx = 1
            for triangle in triangles
                vertices = triangle.vertices
                sdl_vertices[idx] = SDL_Vertex(SDL_FPoint(vertices[1].x, vertices[1].y), vertices[1].color, SDL_FPoint(clamp(vertices[1].u, 0.0, 1.0), clamp(vertices[1].v, 0.0, 1.0)))
                sdl_vertices[idx+1] = SDL_Vertex(SDL_FPoint(vertices[2].x, vertices[2].y), vertices[2].color, SDL_FPoint(clamp(vertices[2].u, 0.0, 1.0), clamp(vertices[2].v, 0.0, 1.0)))
                sdl_vertices[idx+2] = SDL_Vertex(SDL_FPoint(vertices[3].x, vertices[3].y), vertices[3].color, SDL_FPoint(clamp(vertices[3].u, 0.0, 1.0), clamp(vertices[3].v, 0.0, 1.0)))
                idx += 3
            end
            
            if renderer.enable_profiling
                renderer.profiler.vertex_conversion_time += time() - convert_start
            end
            
            # Timing: SDL rendering
            render_start = renderer.enable_profiling ? time() : 0.0
            result = SDL_RenderGeometry(JulGame.Renderer, texture, sdl_vertices, length(sdl_vertices), C_NULL, 0)
            if renderer.enable_profiling
                renderer.profiler.rendering_time += time() - render_start
            end
            
            if result < 0
                println("SDL_RenderGeometry failed: ", unsafe_string(SDL_GetError()))
            else
                triangle_count += length(triangles)
            end
        end
        
        # Print profiling results at interval (frame_count is tracked in Component.render)
        if renderer.enable_profiling
            if renderer.profiler.frame_count % renderer.profile_print_interval == 0
                print_profile(renderer.profiler)
                # Reset all counters
                renderer.profiler.sorting_time = 0.0
                renderer.profiler.grouping_time = 0.0
                renderer.profiler.vertex_conversion_time = 0.0
                renderer.profiler.rendering_time = 0.0
                renderer.profiler.triangle_processing_time = 0.0
                renderer.profiler.transform_time = 0.0
                renderer.profiler.culling_time = 0.0
                renderer.profiler.subdivision_time = 0.0
                renderer.profiler.camera_setup_time = 0.0
                renderer.profiler.mesh_rendering_time = 0.0
                renderer.profiler.box_rendering_time = 0.0
                renderer.profiler.mesh_vertex_access_time = 0.0
                renderer.profiler.mesh_normal_calc_time = 0.0
                renderer.profiler.mesh_material_lookup_time = 0.0
                renderer.profiler.mesh_texture_check_time = 0.0
                renderer.profiler.mesh_lighting_time = 0.0
                renderer.profiler.mesh_uv_processing_time = 0.0
                renderer.profiler.mesh_triangle_add_time = 0.0
                renderer.profiler.triangle_create_time = 0.0
                renderer.profiler.triangle_depth_bias_time = 0.0
                renderer.profiler.triangle_push_time = 0.0
                renderer.profiler.triangle_aabb_time = 0.0
                renderer.profiler.lighting_light_contrib_time = 0.0
                renderer.profiler.lighting_shadow_time = 0.0
                renderer.profiler.lighting_ambient_time = 0.0
                renderer.profiler.material_dict_lookup_time = 0.0
                renderer.profiler.material_color_conv_time = 0.0
                renderer.profiler.total_time = 0.0
                renderer.profiler.frame_count = 0
                renderer.profiler.skipped_sorts = 0
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

    function update(this::SoftwareRenderer3D, deltaTime::Float64)
        # Handle perspective toggle regardless of camera system
        if JulGame.IS_DEBUG && JulGame.InputModule.get_button_pressed("P")
            this.perspective_enabled = !this.perspective_enabled
            this.reverse_sort_triangles = !this.perspective_enabled
        end
        
        # Handle backface culling toggle
        if JulGame.IS_DEBUG && JulGame.InputModule.get_button_pressed("B")
            this.enable_backface_culling = !this.enable_backface_culling
            println("Backface culling: ", this.enable_backface_culling ? "ON" : "OFF")
        end
        
        # Handle winding order toggle
        if JulGame.IS_DEBUG && JulGame.InputModule.get_button_pressed("G")
            this.clockwise_front_faces = !this.clockwise_front_faces
            println("Front face winding: ", this.clockwise_front_faces ? "CLOCKWISE" : "COUNTER-CLOCKWISE")
        end
        
        # Profiling toggle removed - handled by Manager.jl to avoid double-toggle
        
        # Handle fast sort toggle
        if JulGame.IS_DEBUG && JulGame.InputModule.get_button_pressed("N")
            this.use_fast_sort = !this.use_fast_sort
            println("Fast Sort (QuickSort): ", this.use_fast_sort ? "ON (faster, may have minor z-fighting)" : "OFF (stable MergeSort)")
        end
        
        # Handle lighting toggle
        if JulGame.IS_DEBUG && JulGame.InputModule.get_button_pressed("L")
            this.lighting_enabled = !this.lighting_enabled
            println("Lighting: ", this.lighting_enabled ? "ON" : "OFF")
        end
        
        # Handle shadows toggle
        if JulGame.IS_DEBUG && JulGame.InputModule.get_button_pressed("K")
            this.shadows_enabled = !this.shadows_enabled
            println("Shadows: ", this.shadows_enabled ? "ON" : "OFF")
        end
        
        # Handle shadow quality adjustment
        if JulGame.IS_DEBUG && JulGame.InputModule.get_button_pressed("J")
            this.shadow_quality = this.shadow_quality % 3 + 1  # Cycle through 1, 2, 3
            println("Shadow quality: ", this.shadow_quality, " (", 
                   this.shadow_quality == 1 ? "LOW" : this.shadow_quality == 2 ? "MEDIUM" : "HIGH", ")")
        end
        
        # Light manipulation controls
        if JulGame.IS_DEBUG && !isempty(this.lights)
            light = this.lights[1]  # Control the first light
            light_move_speed = 3.0 * 0.016
            
            # Move light with number keys
            if JulGame.InputModule.get_button_held_down("1")
                light.position.x -= light_move_speed
            elseif JulGame.InputModule.get_button_held_down("2")
                light.position.x += light_move_speed
            end
            
            if JulGame.InputModule.get_button_held_down("3")
                light.position.y -= light_move_speed
            elseif JulGame.InputModule.get_button_held_down("4")
                light.position.y += light_move_speed
            end
            
            if JulGame.InputModule.get_button_held_down("5")
                light.position.z -= light_move_speed
            elseif JulGame.InputModule.get_button_held_down("6")
                light.position.z += light_move_speed
            end
        end
    end

    function Component.render(this::SoftwareRenderer3D, main)
        frame_start = this.enable_profiling ? time() : 0.0
        
        update(this, 0.0)
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
        
        # Profile camera setup
        camera_start = this.enable_profiling ? time() : 0.0
        
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
            apply_transform!(this, rotation_matrix(-pitch_rad, -yaw_rad, 0.0))
            apply_transform!(this, translation_matrix(0.0, 0.0, -20.0))
            apply_transform!(this, translation_matrix(-camera_pos.x, -camera_pos.y, -camera_pos.z))
        else
            # Fall back to internal camera system
            apply_transform!(this, scaling_matrix(Float64(this.camera_zoom.x), Float64(this.camera_zoom.y), 1.0))
            apply_transform!(this, rotation_matrix(Float64(-this.camera_rotation.x), Float64(-this.camera_rotation.y), Float64(-this.camera_rotation.z)))
            apply_transform!(this, translation_matrix(0.0, 0.0, -20.0))
            apply_transform!(this, translation_matrix(Float64(-this.camera_position.x), Float64(-this.camera_position.y), Float64(-this.camera_position.z)))
        end
        
        if this.enable_profiling
            this.profiler.camera_setup_time += time() - camera_start
        end
        
        # Profile box rendering
        box_start = this.enable_profiling ? time() : 0.0
        for box in this.boxes
            add_box!(this, box)
        end
        if this.enable_profiling
            this.profiler.box_rendering_time += time() - box_start
        end
        
        # Profile mesh rendering
        mesh_start = this.enable_profiling ? time() : 0.0
        for mesh in this.meshes
            add_mesh!(this, mesh)
        end
        if this.enable_profiling
            this.profiler.mesh_rendering_time += time() - mesh_start
        end
        
        pop_state!(this)
        
        # Flush all triangles (already has internal profiling)
        triangle_count = flush_triangles!(this)
        
        # Update total frame time and frame count
        if this.enable_profiling
            this.profiler.total_time += time() - frame_start
            this.profiler.frame_count += 1
        end
        
        if JulGame.IS_DEBUG
            # println("Rendered $triangle_count triangles")
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
                                stroke_color::SDL_Color = SDL_Color(0, 0, 0, 255),
                                normalize_uv::Bool = false)::Union{RenderMesh, Nothing}
        return load_mesh_from_file!(renderer, file_path, position, rotation, scale, fill_color, stroke_color, normalize_uv)
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

    # Depth bias configuration functions
    function set_depth_bias!(renderer::SoftwareRenderer3D, factor::Float64, enabled::Bool = true)
        renderer.depth_bias_factor = factor
        renderer.enable_depth_bias = enabled
    end

    function enable_depth_bias!(renderer::SoftwareRenderer3D, enabled::Bool = true)
        renderer.enable_depth_bias = enabled
    end

    function get_depth_bias_settings(renderer::SoftwareRenderer3D)
        return (
            enabled = renderer.enable_depth_bias,
            factor = renderer.depth_bias_factor
        )
    end

    # Enhanced lighting system functions
    
    # Calculate lighting contribution from a single light
    function calculate_light_contribution(light::Light3D, surface_pos::Vec3D, normal::Vec3D)::Vec3D
        if !light.enabled
            return Vec3D(0, 0, 0)
        end
        
        light_contribution = Vec3D(0, 0, 0)
        
        if light.type == DIRECTIONAL_LIGHT
            # Directional light - light direction is constant
            light_dir = normalize(light.direction)
            dp = dot(normal, -light_dir)  # Negative because light direction points away from light
            
            if dp > 0  # Only contribute if surface faces the light
                intensity = dp * light.intensity
                light_contribution = Vec3D(light.color.x * intensity, light.color.y * intensity, light.color.z * intensity)
            end
            
        elseif light.type == POINT_LIGHT
            # Point light - calculate direction from surface to light
            light_vec = Vec3D(light.position.x - surface_pos.x, 
                             light.position.y - surface_pos.y, 
                             light.position.z - surface_pos.z)
            distance = length_of(light_vec)
            
            if distance > 0 && distance < light.range
                light_dir = Vec3D(light_vec.x / distance, light_vec.y / distance, light_vec.z / distance)
                dp = dot(normal, light_dir)
                
                if dp > 0  # Only contribute if surface faces the light
                    # Apply distance attenuation
                    attenuation = 1.0 / (1.0 + 0.09 * distance + 0.032 * distance * distance)
                    intensity = dp * light.intensity * attenuation
                    light_contribution = Vec3D(light.color.x * intensity, light.color.y * intensity, light.color.z * intensity)
                end
            end
            
        elseif light.type == SPOT_LIGHT
            # Spot light - like point light but with cone angle restriction
            light_vec = Vec3D(light.position.x - surface_pos.x, 
                             light.position.y - surface_pos.y, 
                             light.position.z - surface_pos.z)
            distance = length_of(light_vec)
            
            if distance > 0 && distance < light.range
                light_dir = Vec3D(light_vec.x / distance, light_vec.y / distance, light_vec.z / distance)
                
                # Check if within spot cone
                spot_factor = dot(-light_dir, normalize(light.direction))
                cos_spot_angle = cos(light.spot_angle)
                
                if spot_factor > cos_spot_angle
                    dp = dot(normal, light_dir)
                    
                    if dp > 0  # Only contribute if surface faces the light
                        # Apply distance attenuation and spot cone falloff
                        attenuation = 1.0 / (1.0 + 0.09 * distance + 0.032 * distance * distance)
                        cone_factor = (spot_factor - cos_spot_angle) / (1.0 - cos_spot_angle)
                        intensity = dp * light.intensity * attenuation * cone_factor
                        light_contribution = Vec3D(light.color.x * intensity, light.color.y * intensity, light.color.z * intensity)
                    end
                end
            end
        end
        
        return light_contribution
    end
    
    # Simple shadow calculation using ray casting
    function calculate_shadow_factor(renderer::SoftwareRenderer3D, light::Light3D, surface_pos::Vec3D)::Float64
        if !renderer.shadows_enabled || !light.cast_shadows
            return 1.0  # No shadow
        end
        
        shadow_factor = 1.0
        
        # For directional lights, use light direction
        # For point/spot lights, calculate direction from surface to light
        shadow_ray_dir = if light.type == DIRECTIONAL_LIGHT
            normalize(-light.direction)
        else
            light_vec = Vec3D(light.position.x - surface_pos.x, 
                             light.position.y - surface_pos.y, 
                             light.position.z - surface_pos.z)
            distance = length_of(light_vec)
            if distance > 0
                Vec3D(light_vec.x / distance, light_vec.y / distance, light_vec.z / distance)
            else
                Vec3D(0, 1, 0)  # Default up direction
            end
        end
        
        # Simple shadow casting - check if any triangles block the light
        # This is a basic implementation - in production you'd use shadow maps
        shadow_ray_start = Vec3D(surface_pos.x + shadow_ray_dir.x * light.shadow_bias,
                                surface_pos.y + shadow_ray_dir.y * light.shadow_bias,
                                surface_pos.z + shadow_ray_dir.z * light.shadow_bias)
        
        # For performance, we limit shadow ray distance based on light type
        max_shadow_distance = if light.type == DIRECTIONAL_LIGHT
            renderer.max_shadow_distance
        else
            min(light.range, renderer.max_shadow_distance)
        end
        
        # Sample multiple points along the shadow ray for soft shadows
        samples = renderer.shadow_quality * 2  # Quality affects sample count
        shadow_hits = 0
        
        for i in 1:samples
            sample_distance = (Float64(i) / Float64(samples)) * max_shadow_distance
            sample_pos = Vec3D(shadow_ray_start.x + shadow_ray_dir.x * sample_distance,
                              shadow_ray_start.y + shadow_ray_dir.y * sample_distance,
                              shadow_ray_start.z + shadow_ray_dir.z * sample_distance)
            
            # Simple occlusion test - check if sample point is inside any mesh bounding box
            # This is very basic - a real implementation would do proper ray-triangle intersection
            for mesh in renderer.meshes
                if is_point_in_mesh_bounds(sample_pos, mesh)
                    shadow_hits += 1
                    break  # One hit per sample is enough
                end
            end
        end
        
        # Calculate shadow factor based on hit ratio
        if samples > 0
            shadow_factor = 1.0 - (Float64(shadow_hits) / Float64(samples))
        end
        
        return clamp(shadow_factor, 0.1, 1.0)  # Always allow some light through
    end
    
    # Check if a point is within mesh bounds (very basic bounds check)
    # Uses cached bounding box for performance
    # NOTE: point is in world space, bounds are in model space - we need to transform
    function is_point_in_mesh_bounds(point::Vec3D, mesh::RenderMesh)::Bool
        if isempty(mesh.vertices)
            return false
        end
        
        # Use cached bounds if available, otherwise compute and cache them
        if mesh.cached_bounds_min === nothing || mesh.cached_bounds_max === nothing
            compute_mesh_bounds!(mesh)
        end
        
        # If still nothing after computation, mesh is invalid
        if mesh.cached_bounds_min === nothing || mesh.cached_bounds_max === nothing
            return false
        end
        
        # Transform point from world space to model space
        # The mesh transform is: T * R * S (translation * rotation * scale)
        # Inverse transform is: S^-1 * R^-1 * T^-1
        
        # 1. T^-1: Subtract mesh position (undo translation)
        local_point = Vec3D(point.x - mesh.position.x, 
                           point.y - mesh.position.y, 
                           point.z - mesh.position.z)
        
        # 2. R^-1: TODO - Apply inverse rotation (complex, skipped for now)
        # This may cause false positives/negatives for rotated meshes
        # For now, this works if meshes aren't rotated
        
        # 3. S^-1: Apply inverse scale (undo scale)
        if mesh.scale.x != 0.0 && mesh.scale.y != 0.0 && mesh.scale.z != 0.0
            local_point = Vec3D(local_point.x / mesh.scale.x,
                               local_point.y / mesh.scale.y,
                               local_point.z / mesh.scale.z)
        end
        
        # Check if transformed point is within cached bounds (model space)
        return (local_point.x >= mesh.cached_bounds_min.x && local_point.x <= mesh.cached_bounds_max.x &&
                local_point.y >= mesh.cached_bounds_min.y && local_point.y <= mesh.cached_bounds_max.y &&
                local_point.z >= mesh.cached_bounds_min.z && local_point.z <= mesh.cached_bounds_max.z)
    end
    
    # Calculate lighting factor for a surface (returns 0.0 to 1.0)
    function calculate_lighting_factor(renderer::SoftwareRenderer3D, normal::Vec3D, v1::Vec3D, v2::Vec3D, v3::Vec3D)::Float64
        # Calculate surface center position for lighting calculations
        surface_pos = Vec3D((v1.x + v2.x + v3.x) / 3.0, (v1.y + v2.y + v3.y) / 3.0, (v1.z + v2.z + v3.z) / 3.0)
        
        # Profile: Ambient light
        ambient_start = renderer.enable_profiling ? time() : 0.0
        total_intensity = (renderer.ambient_light.x + renderer.ambient_light.y + renderer.ambient_light.z) / 3.0
        if renderer.enable_profiling
            renderer.profiler.lighting_ambient_time += time() - ambient_start
        end
        
        # Add contribution from each light
        for light in renderer.lights
            if light.enabled
                # Profile: Light contribution
                contrib_start = renderer.enable_profiling ? time() : 0.0
                light_contrib = calculate_light_contribution(light, surface_pos, normal)
                if renderer.enable_profiling
                    renderer.profiler.lighting_light_contrib_time += time() - contrib_start
                end
                
                # Profile: Shadow factor
                shadow_start = renderer.enable_profiling ? time() : 0.0
                shadow_factor = calculate_shadow_factor(renderer, light, surface_pos)
                if renderer.enable_profiling
                    renderer.profiler.lighting_shadow_time += time() - shadow_start
                end
                
                # Add light intensity (average RGB as overall intensity)
                light_intensity = (light_contrib.x + light_contrib.y + light_contrib.z) / 3.0 * shadow_factor
                total_intensity += light_intensity
            end
        end
        
        # Clamp to reasonable range
        return clamp(total_intensity, 0.1, 1.0)
    end
    
    # Apply enhanced lighting to a surface (legacy function for non-textured surfaces)
    function apply_enhanced_lighting(renderer::SoftwareRenderer3D, base_color::Vec3D, normal::Vec3D, v1::Vec3D, v2::Vec3D, v3::Vec3D)::Vec3D
        lighting_factor = calculate_lighting_factor(renderer, normal, v1, v2, v3)
        
        return Vec3D(base_color.x * lighting_factor,
                    base_color.y * lighting_factor,
                    base_color.z * lighting_factor,
                    base_color.w)
    end
    
    # Lighting system management functions
    function add_light!(renderer::SoftwareRenderer3D, light::Light3D)::Int
        push!(renderer.lights, light)
        return length(renderer.lights)
    end
    
    function remove_light!(renderer::SoftwareRenderer3D, index::Int)::Bool
        if index > 0 && index <= length(renderer.lights)
            deleteat!(renderer.lights, index)
            return true
        end
        return false
    end
    
    function clear_lights!(renderer::SoftwareRenderer3D)
        empty!(renderer.lights)
    end
    
    function set_ambient_light!(renderer::SoftwareRenderer3D, color::Vec3D)
        renderer.ambient_light = color
    end
    
    function enable_lighting!(renderer::SoftwareRenderer3D, enable::Bool = true)
        renderer.lighting_enabled = enable
    end
    
    function disable_lighting!(renderer::SoftwareRenderer3D)
        renderer.lighting_enabled = false
    end
    
    function enable_shadows!(renderer::SoftwareRenderer3D, enable::Bool = true)
        renderer.shadows_enabled = enable
    end
    
    function disable_shadows!(renderer::SoftwareRenderer3D)
        renderer.shadows_enabled = false
    end
    
    function set_shadow_quality!(renderer::SoftwareRenderer3D, quality::Int)
        renderer.shadow_quality = clamp(quality, 1, 3)
    end
    
    function set_max_shadow_distance!(renderer::SoftwareRenderer3D, distance::Float64)
        renderer.max_shadow_distance = max(distance, 1.0)
    end
    
    # Convenience functions for creating common light types
    function create_directional_light(direction::Vec3D = Vec3D(0, -1, 0), color::Vec3D = Vec3D(1, 1, 1), intensity::Float64 = 1.0)::Light3D
        return Light3D(DIRECTIONAL_LIGHT, Vec3D(0, 0, 0), direction, color, intensity, 100.0, π/4, true, 0.001, true)
    end
    
    function create_point_light(position::Vec3D, color::Vec3D = Vec3D(1, 1, 1), intensity::Float64 = 1.0, range::Float64 = 10.0)::Light3D
        return Light3D(POINT_LIGHT, position, Vec3D(0, -1, 0), color, intensity, range, π/4, true, 0.001, true)
    end
    
    function create_spot_light(position::Vec3D, direction::Vec3D, color::Vec3D = Vec3D(1, 1, 1), intensity::Float64 = 1.0, range::Float64 = 10.0, angle::Float64 = π/6)::Light3D
        return Light3D(SPOT_LIGHT, position, direction, color, intensity, range, angle, true, 0.001, true)
    end
    
    # Get lighting system information
    function get_lighting_info(renderer::SoftwareRenderer3D)::String
        info = "=== LIGHTING SYSTEM INFO ===\n"
        info *= "Lighting enabled: $(renderer.lighting_enabled)\n"
        info *= "Shadows enabled: $(renderer.shadows_enabled)\n"
        info *= "Shadow quality: $(renderer.shadow_quality) ($(renderer.shadow_quality == 1 ? "LOW" : renderer.shadow_quality == 2 ? "MEDIUM" : "HIGH"))\n"
        info *= "Ambient light: RGB($(renderer.ambient_light.x), $(renderer.ambient_light.y), $(renderer.ambient_light.z))\n"
        info *= "Number of lights: $(length(renderer.lights))\n"
        
        for (i, light) in enumerate(renderer.lights)
            light_type = light.type == DIRECTIONAL_LIGHT ? "DIRECTIONAL" : 
                        light.type == POINT_LIGHT ? "POINT" : "SPOT"
            info *= "Light $i: $light_type, Enabled: $(light.enabled), Intensity: $(light.intensity)\n"
            if light.type != DIRECTIONAL_LIGHT
                info *= "  Position: ($(light.position.x), $(light.position.y), $(light.position.z))\n"
            end
            if light.type != POINT_LIGHT
                info *= "  Direction: ($(light.direction.x), $(light.direction.y), $(light.direction.z))\n"
            end
            info *= "  Color: RGB($(light.color.x), $(light.color.y), $(light.color.z))\n"
            info *= "  Casts shadows: $(light.cast_shadows)\n"
        end
        
        info *= "\n=== DEBUG CONTROLS ===\n"
        info *= "L - Toggle lighting\n"
        info *= "K - Toggle shadows\n"  
        info *= "J - Cycle shadow quality\n"
        info *= "1/2 - Move light left/right\n"
        info *= "3/4 - Move light down/up\n"
        info *= "5/6 - Move light back/forward\n"
        
        return info
    end

    # Simple lighting calculation (legacy function, kept for compatibility)
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

    # Profiling control functions
    function enable_profiling!(renderer::SoftwareRenderer3D, print_interval::Int = 60)
        renderer.enable_profiling = true
        renderer.profile_print_interval = print_interval
        # Reset all profiler fields
        renderer.profiler.sorting_time = 0.0
        renderer.profiler.grouping_time = 0.0
        renderer.profiler.vertex_conversion_time = 0.0
        renderer.profiler.rendering_time = 0.0
        renderer.profiler.triangle_processing_time = 0.0
        renderer.profiler.transform_time = 0.0
        renderer.profiler.culling_time = 0.0
        renderer.profiler.subdivision_time = 0.0
        renderer.profiler.camera_setup_time = 0.0
        renderer.profiler.mesh_rendering_time = 0.0
        renderer.profiler.box_rendering_time = 0.0
        renderer.profiler.mesh_vertex_access_time = 0.0
        renderer.profiler.mesh_normal_calc_time = 0.0
        renderer.profiler.mesh_material_lookup_time = 0.0
        renderer.profiler.mesh_texture_check_time = 0.0
        renderer.profiler.mesh_lighting_time = 0.0
        renderer.profiler.mesh_uv_processing_time = 0.0
        renderer.profiler.mesh_triangle_add_time = 0.0
        renderer.profiler.triangle_create_time = 0.0
        renderer.profiler.triangle_depth_bias_time = 0.0
        renderer.profiler.triangle_push_time = 0.0
        renderer.profiler.triangle_aabb_time = 0.0
        renderer.profiler.lighting_light_contrib_time = 0.0
        renderer.profiler.lighting_shadow_time = 0.0
        renderer.profiler.lighting_ambient_time = 0.0
        renderer.profiler.material_dict_lookup_time = 0.0
        renderer.profiler.material_color_conv_time = 0.0
        renderer.profiler.total_time = 0.0
        renderer.profiler.frame_count = 0
        renderer.profiler.skipped_sorts = 0
        println("Profiling enabled: stats will print every $print_interval frames")
    end
    
    function disable_profiling!(renderer::SoftwareRenderer3D)
        renderer.enable_profiling = false
        println("Profiling disabled")
    end
    
    function print_profiling_stats(renderer::SoftwareRenderer3D)
        print_profile(renderer.profiler)
    end
    
    # Get current profiling stats for on-screen display
    function get_profiling_stats(renderer::SoftwareRenderer3D)::Union{Nothing, NamedTuple}
        if !renderer.enable_profiling || renderer.profiler.frame_count == 0
            return nothing
        end
        
        avg_sort = renderer.profiler.sorting_time / renderer.profiler.frame_count * 1000
        avg_group = renderer.profiler.grouping_time / renderer.profiler.frame_count * 1000
        avg_convert = renderer.profiler.vertex_conversion_time / renderer.profiler.frame_count * 1000
        avg_render = renderer.profiler.rendering_time / renderer.profiler.frame_count * 1000
        avg_tri_process = renderer.profiler.triangle_processing_time / renderer.profiler.frame_count * 1000
        avg_transform = renderer.profiler.transform_time / renderer.profiler.frame_count * 1000
        avg_culling = renderer.profiler.culling_time / renderer.profiler.frame_count * 1000
        avg_subdiv = renderer.profiler.subdivision_time / renderer.profiler.frame_count * 1000
        avg_camera = renderer.profiler.camera_setup_time / renderer.profiler.frame_count * 1000
        avg_mesh = renderer.profiler.mesh_rendering_time / renderer.profiler.frame_count * 1000
        avg_box = renderer.profiler.box_rendering_time / renderer.profiler.frame_count * 1000
        avg_total = renderer.profiler.total_time / renderer.profiler.frame_count * 1000
        skip_percent = renderer.profiler.skipped_sorts / renderer.profiler.frame_count * 100
        
        return (
            sorting_ms = avg_sort,
            grouping_ms = avg_group,
            conversion_ms = avg_convert,
            rendering_ms = avg_render,
            triangle_processing_ms = avg_tri_process,
            transform_ms = avg_transform,
            culling_ms = avg_culling,
            subdivision_ms = avg_subdiv,
            camera_setup_ms = avg_camera,
            mesh_rendering_ms = avg_mesh,
            box_rendering_ms = avg_box,
            total_ms = avg_total,
            skipped_sorts_percent = skip_percent,
            frame_count = renderer.profiler.frame_count
        )
    end
    
    # Fast sort control
    function enable_fast_sort!(renderer::SoftwareRenderer3D, enable::Bool = true)
        renderer.use_fast_sort = enable
        sort_type = enable ? "QuickSort (faster, less stable)" : "MergeSort (stable, slower)"
        println("Sort algorithm: $sort_type")
    end
    
    # Cached sort control (frame coherency)
    function enable_cached_sort!(renderer::SoftwareRenderer3D, enable::Bool = true, 
                                 move_threshold::Float64 = 0.5, rotate_threshold::Float64 = 2.0)
        renderer.use_cached_sort = enable
        renderer.camera_move_threshold = move_threshold
        renderer.camera_rotate_threshold = rotate_threshold
        
        if enable
            println("Sort caching: ENABLED (move threshold: $move_threshold, rotate threshold: $rotate_threshold°)")
            println("  → Sort will be skipped if camera moves < threshold (HUGE speedup!)")
        else
            println("Sort caching: DISABLED (will sort every frame)")
        end
    end

end 